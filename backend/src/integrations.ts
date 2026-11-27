import{Router}from'express';import{z}from'zod';import crypto from'node:crypto';import PDFDocument from'pdfkit';import{db}from'./db.js';import{authenticate,requireTenant}from'./middleware.js';import type{AuthRequest}from'./types.js';import{AppError}from'./errors.js';
export const integrationRouter=Router();integrationRouter.use(authenticate,requireTenant);const required=(name:string)=>{const value=process.env[name];if(!value)throw new AppError(503,`${name} is not configured`,'NOT_CONFIGURED');return value;};
async function paymentInvoice(req:AuthRequest,invoiceId:string){const elevated=['ADMIN','MANAGER','SUPER_ADMIN'].includes(req.identity!.role);if(!elevated&&req.identity!.role!=='CUSTOMER')throw new AppError(403,'Payment access denied','PAYMENT_FORBIDDEN');const invoice=await db.invoice.findFirst({where:{id:invoiceId,businessId:req.identity!.businessId,...(elevated?{}:{booking:{customer:{userId:req.identity!.userId}}})}});if(!invoice)throw new AppError(404,'Invoice not found');return invoice;}
integrationRouter.post('/ai/assist',async(req:AuthRequest,res)=>{const input=z.object({task:z.string(),content:z.string().min(3).max(12000)}).parse(req.body);const response=await fetch(required('AI_PROVIDER_URL'),{method:'POST',headers:{'Content-Type':'application/json','Authorization':`Bearer ${required('AI_PROVIDER_KEY')}`},body:JSON.stringify({model:process.env.AI_MODEL,input:`Task: ${input.task}\n${input.content}`})});if(response.status===429)throw new AppError(429,'AI rate limit reached','AI_RATE_LIMIT');if(!response.ok)throw new AppError(502,'AI provider failed','AI_PROVIDER_ERROR');res.json({data:{draft:await response.json(),requiresReview:true,disclaimer:'Human review required. AI cannot approve charges, refunds, or completion.'}});});
integrationRouter.get('/maps/route',async(req:AuthRequest,res)=>{const q=z.object({origin:z.string(),destination:z.string()}).parse(req.query);const url=new URL('https://maps.googleapis.com/maps/api/directions/json');url.searchParams.set('origin',q.origin);url.searchParams.set('destination',q.destination);url.searchParams.set('key',required('GOOGLE_MAPS_SERVER_KEY'));const response=await fetch(url);if(!response.ok)throw new AppError(502,'Route provider unavailable','MAPS_PROVIDER_ERROR');res.json({data:await response.json()});});
integrationRouter.put('/technician/location',async(req:AuthRequest,res)=>{const body=z.object({jobId:z.string().uuid(),latitude:z.number().min(-90).max(90),longitude:z.number().min(-180).max(180),consent:z.literal(true)}).parse(req.body);const technician=await db.technician.findFirst({where:{userId:req.identity!.userId,businessId:req.identity!.businessId,assignments:{some:{jobId:body.jobId,unassignedAt:null}}}});if(!technician)throw new AppError(403,'Active assigned job and consent required','LOCATION_FORBIDDEN');const data=await db.technician.update({where:{id:technician.id},data:{locationLat:body.latitude,locationLng:body.longitude,locationAt:new Date(),locationConsent:true}});res.json({data:{latitude:data.locationLat,longitude:data.locationLng,timestamp:data.locationAt}});});
integrationRouter.get('/bookings/:id/chat',async(req:AuthRequest,res)=>{await authorized(req);res.json({data:await db.chatMessage.findMany({where:{bookingId:req.params.id},orderBy:{createdAt:'asc'}})});});integrationRouter.post('/bookings/:id/chat',async(req:AuthRequest,res)=>{await authorized(req);const message=z.object({message:z.string().min(1).max(4000)}).parse(req.body).message;res.status(201).json({data:await db.chatMessage.create({data:{bookingId:req.params.id,senderId:req.identity!.userId,body:message}})});});
integrationRouter.get('/notifications',async(req:AuthRequest,res)=>res.json({data:await db.notification.findMany({where:{userId:req.identity!.userId},orderBy:{createdAt:'desc'},take:100})}));integrationRouter.post('/notifications/device',async(req:AuthRequest,res)=>{const body=z.object({token:z.string().min(20),platform:z.string()}).parse(req.body);res.json({data:await db.deviceToken.upsert({where:{token:body.token},update:{userId:req.identity!.userId,enabled:true},create:{...body,userId:req.identity!.userId}})});});
integrationRouter.get('/invoices/:id/pdf',async(req:AuthRequest,res)=>{const elevated=['ADMIN','MANAGER','SUPER_ADMIN'].includes(req.identity!.role);const access=elevated?{}:{booking:{customer:{userId:req.identity!.userId}}};const invoice=await db.invoice.findFirst({where:{id:req.params.id,businessId:req.identity!.businessId,...access},include:{items:true,booking:{include:{customer:{include:{user:true}},service:true}}}});if(!invoice)throw new AppError(404,'Invoice not found');res.type('application/pdf').attachment(`${invoice.number}.pdf`);const doc=new PDFDocument({margin:48});doc.pipe(res);doc.fontSize(24).fillColor('#6738E8').text('FieldOps Pro').moveDown().fontSize(16).fillColor('#17152A').text(`Invoice ${invoice.number}`).fontSize(10).text(`Customer: ${invoice.booking.customer.user.name}`).text(`Booking: ${invoice.bookingId}`).text(`Service: ${invoice.booking.service.name}`);doc.moveDown();for(const item of invoice.items)doc.text(`${item.description}  ${item.quantity} × ${item.unitPrice}`);doc.moveDown().text(`Subtotal: ${invoice.subtotal}`).text(`Tax: ${invoice.tax}`).fontSize(16).text(`Total: ${invoice.total}`).fontSize(10).text(`Payment status: ${invoice.status}`);doc.end();});
integrationRouter.post('/sync',async(req:AuthRequest,res)=>{const body=z.object({idempotencyKey:z.string().min(12),operation:z.string(),entityId:z.string().uuid(),payload:z.record(z.string(),z.unknown())}).parse(req.body);const scopedKey=`${req.identity!.businessId}:${body.idempotencyKey}`;const existing=await db.syncOperation.findUnique({where:{idempotencyKey:scopedKey}});if(existing)return void res.json({data:existing,duplicate:true});const data=await db.syncOperation.create({data:{...body,idempotencyKey:scopedKey,payload:body.payload as any,businessId:req.identity!.businessId,userId:req.identity!.userId}});res.status(201).json({data,duplicate:false});});
integrationRouter.post('/payments/create-order',async(req:AuthRequest,res)=>{
  const key=required('RAZORPAY_KEY_ID'),secret=required('RAZORPAY_KEY_SECRET');
  const invoiceId=z.object({invoiceId:z.string().uuid()}).parse(req.body).invoiceId;
  const invoice=await paymentInvoice(req,invoiceId);
  const requestKey=req.header('Idempotency-Key');
  if(!requestKey)throw new AppError(422,'Idempotency-Key is required');
  const idempotencyKey=`online:${req.identity!.businessId}:${requestKey}`;
  const existing=await db.payment.findUnique({where:{idempotencyKey}});
  if(existing){if(existing.invoiceId!==invoiceId)throw new AppError(409,'Idempotency key was already used for another invoice','IDEMPOTENCY_CONFLICT');return void res.json({data:existing,duplicate:true});}
  const verifiedPayments=await db.payment.findMany({where:{invoiceId,status:{in:['PAID','REFUNDED']}},include:{refunds:{where:{status:'SUCCEEDED'}}}});
  const verifiedNet=verifiedPayments.reduce((total,payment)=>total+Number(payment.amount)-payment.refunds.reduce((sum,refund)=>sum+Number(refund.amount),0),0);
  const outstanding=Number(invoice.total)-verifiedNet;
  if(outstanding<=0.000001)throw new AppError(409,'Invoice is already fully paid','INVOICE_ALREADY_PAID');
  const response=await fetch('https://api.razorpay.com/v1/orders',{method:'POST',headers:{'Content-Type':'application/json','Authorization':`Basic ${Buffer.from(`${key}:${secret}`).toString('base64')}`},body:JSON.stringify({amount:Math.round(outstanding*100),currency:'INR',receipt:invoice.number})});
  if(!response.ok)throw new AppError(502,'Payment provider rejected order','PAYMENT_PROVIDER_ERROR');
  const order=await response.json()as{id?:string};
  if(!order.id)throw new AppError(502,'Payment provider returned an invalid order','PAYMENT_PROVIDER_ERROR');
  const data=await db.payment.create({data:{invoiceId,provider:'RAZORPAY',method:'ONLINE',currency:'INR',providerOrderId:order.id,idempotencyKey,amount:outstanding}});
  res.status(201).json({data,providerKeyId:key});
});
integrationRouter.post('/payments/verify',async(req:AuthRequest,res)=>{
  const secret=required('RAZORPAY_KEY_SECRET');
  const body=z.object({orderId:z.string(),paymentId:z.string(),signature:z.string().length(64)}).parse(req.body);
  const expected=crypto.createHmac('sha256',secret).update(`${body.orderId}|${body.paymentId}`).digest('hex');
  if(!crypto.timingSafeEqual(Buffer.from(expected),Buffer.from(body.signature)))throw new AppError(400,'Payment signature invalid','INVALID_PAYMENT_SIGNATURE');
  const elevated=['ADMIN','MANAGER','SUPER_ADMIN'].includes(req.identity!.role);
  if(!elevated&&req.identity!.role!=='CUSTOMER')throw new AppError(403,'Payment access denied','PAYMENT_FORBIDDEN');
  const payment=await db.payment.findFirst({where:{providerOrderId:body.orderId,invoice:{businessId:req.identity!.businessId,...(elevated?{}:{booking:{customer:{userId:req.identity!.userId}}})}},include:{invoice:true}});
  if(!payment)throw new AppError(404,'Payment order not found');
  if(payment.status==='PAID'){
    if(payment.providerPaymentId!==body.paymentId)throw new AppError(409,'Payment order was verified with a different payment','PAYMENT_CONFLICT');
    return void res.json({data:payment,serverVerified:true,duplicate:true});
  }
  const data=await db.$transaction(async tx=>{
    const updated=await tx.payment.update({where:{id:payment.id},data:{providerPaymentId:body.paymentId,status:'PAID',verifiedAt:new Date(),failureReason:null}});
    const payments=await tx.payment.findMany({where:{invoiceId:payment.invoiceId,status:{in:['PAID','REFUNDED']}},include:{refunds:{where:{status:'SUCCEEDED'}}}});
    const verifiedNet=payments.reduce((total,item)=>total+Number(item.amount)-item.refunds.reduce((sum,refund)=>sum+Number(refund.amount),0),0);
    if(verifiedNet+0.000001>=Number(payment.invoice.total))await tx.invoice.update({where:{id:payment.invoiceId},data:{status:'PAID'}});
    await tx.auditLog.create({data:{businessId:req.identity!.businessId,actorId:req.identity!.userId,action:'ONLINE_PAYMENT_VERIFIED',entity:'Payment',entityId:payment.id,metadata:{provider:'RAZORPAY',providerPaymentId:body.paymentId,verifiedNet}}});
    return updated;
  });
  res.json({data,serverVerified:true});
});
async function authorized(req:AuthRequest){const booking=await db.booking.findFirst({where:{id:req.params.id,businessId:req.identity!.businessId,OR:[{customer:{userId:req.identity!.userId}},{job:{assignments:{some:{technician:{userId:req.identity!.userId},unassignedAt:null}}}}]}});if(!booking)throw new AppError(403,'Booking access denied','CHAT_FORBIDDEN');}
