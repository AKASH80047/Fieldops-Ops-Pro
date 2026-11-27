import{Router}from'express';import crypto from'node:crypto';import{z}from'zod';import{db}from'./db.js';import{authenticate,allow,requireTenant}from'./middleware.js';import type{AuthRequest}from'./types.js';import{AppError}from'./errors.js';import{adminRouter}from'./admin.js';import{adminAnalyticsRouter}from'./admin-analytics.js';import{financeRouter}from'./finance.js';
import{technicianOnboardingRouter}from'./technician-onboarding.js';
import{dispatchPushToUsers}from'./notification-dispatcher.js';
export const apiRouter=Router();apiRouter.use(authenticate,requireTenant);const page=z.object({page:z.coerce.number().min(1).default(1),limit:z.coerce.number().min(1).max(100).default(20)});const requiredTechnicianDocuments=[...new Set([...(process.env.TECHNICIAN_REQUIRED_DOCUMENT_TYPES??'IDENTITY,ADDRESS').split(',').map(value=>value.trim()).filter(Boolean),'LIVE_SELFIE'])];
apiRouter.get('/services',async(req:AuthRequest,res)=>{const q=page.parse(req.query);const where={businessId:req.identity!.businessId,active:true,deletedAt:null};const[data,total]=await db.$transaction([db.service.findMany({where,include:{category:true},skip:(q.page-1)*q.limit,take:q.limit}),db.service.count({where})]);res.json({data,meta:{...q,total}});});apiRouter.get('/services/:id',async(req:AuthRequest,res)=>{const data=await db.service.findFirst({where:{id:req.params.id,businessId:req.identity!.businessId,deletedAt:null},include:{category:true}});if(!data)throw new AppError(404,'Service not found');res.json({data});});apiRouter.get('/service-categories',async(req:AuthRequest,res)=>res.json({data:await db.serviceCategory.findMany({where:{businessId:req.identity!.businessId,active:true,deletedAt:null}})}));
apiRouter.get('/bookings',async(req:AuthRequest,res)=>{const customer=await db.customer.findFirst({where:{userId:req.identity!.userId,businessId:req.identity!.businessId}});if(!customer)throw new AppError(403,'Customer profile required');res.json({data:await db.booking.findMany({where:{businessId:req.identity!.businessId,customerId:customer.id,deletedAt:null},include:{service:true,address:true,job:true},orderBy:{createdAt:'desc'}})});});
apiRouter.post('/bookings',allow('CUSTOMER'),async(req:AuthRequest,res)=>{
  const input=z.object({serviceId:z.string().uuid(),addressId:z.string().uuid(),scheduledAt:z.coerce.date(),instructions:z.string().max(2000).optional()}).parse(req.body);
  if(input.scheduledAt.getTime()<Date.now())throw new AppError(422,'Booking time must be in the future','INVALID_SCHEDULE');
  const customer=await db.customer.findFirst({where:{userId:req.identity!.userId,businessId:req.identity!.businessId}});
  const service=await db.service.findFirst({where:{id:input.serviceId,businessId:req.identity!.businessId,active:true,deletedAt:null},include:{coverage:{where:{active:true},include:{serviceArea:true}}}});
  const address=customer&&await db.address.findFirst({where:{id:input.addressId,customerId:customer.id}});
  if(!customer||!service||!address)throw new AppError(422,'Invalid customer, service, or address');
  if(service.coverage.length>0&&!service.coverage.some(item=>item.serviceArea.active&&item.serviceArea.postalCodes.includes(address.postalCode)))throw new AppError(422,'This service is not available at the selected address','SERVICE_AREA_UNAVAILABLE');
  const subtotal=Number(service.basePrice);
  const tax=subtotal*Number(service.taxRate)/100;
  const total=subtotal+tax;
  const coveredServiceAreaIds=service.coverage.filter(item=>item.active&&item.serviceArea.active&&item.serviceArea.postalCodes.includes(address.postalCode)).map(item=>item.serviceAreaId);
  const invoiceNumber=`INV-${Date.now()}-${crypto.randomUUID().slice(0,8).toUpperCase()}`;
  const data=await db.$transaction(async tx=>{
    const booking=await tx.booking.create({
      data:{
        businessId:req.identity!.businessId,
        customerId:customer.id,
        serviceId:service.id,
        addressId:address.id,
        scheduledAt:input.scheduledAt,
        instructions:input.instructions,
        estimatedPrice:total,
        job:{create:{}},
        invoice:{
          create:{
            businessId:req.identity!.businessId,
            number:invoiceNumber,
            subtotal,
            tax,
            total,
            status:'PENDING',
            items:{create:{description:service.name,quantity:1,unitPrice:subtotal,tax}},
          },
        },
      },
      include:{job:true,invoice:{include:{items:true}}},
    });
    await tx.auditLog.create({data:{businessId:req.identity!.businessId,actorId:req.identity!.userId,action:'BOOKING_CREATED',entity:'Booking',entityId:booking.id,metadata:{invoiceId:booking.invoice?.id,estimatedTotal:total}}});
    const candidates=await tx.technician.findMany({where:{businessId:req.identity!.businessId,verificationStatus:'APPROVED',available:true,profileCompletedAt:{not:null},serviceAreas:{some:{active:true,...(coveredServiceAreaIds.length>0?{serviceAreaId:{in:coveredServiceAreaIds}}:{}),serviceArea:{active:true,postalCodes:{has:address.postalCode}}}}},include:{documents:{select:{type:true,status:true}}}});
    const requiredSkills=new Set(service.requiredSkills.map(skill=>skill.trim().toLowerCase()));
    const eligible=candidates.filter(technician=>{const skills=new Set(technician.skills.map(skill=>skill.trim().toLowerCase()));const skillMatch=[...requiredSkills].every(skill=>skills.has(skill));const documentsApproved=requiredTechnicianDocuments.every(type=>technician.documents.some(document=>document.type===type&&document.status==='APPROVED'));return skillMatch&&documentsApproved;});
    if(eligible.length>0)await tx.notification.createMany({data:eligible.map(technician=>({userId:technician.userId,title:'New nearby job',body:`${service.name} is available in ${address.city}.`,type:'JOB_OPPORTUNITY'}))});
    return {booking,eligibleUserIds:eligible.map(technician=>technician.userId)};
  });
  if(data.eligibleUserIds.length>0){
    void dispatchPushToUsers(data.eligibleUserIds,{title:'New nearby job',body:`${service.name} is available in ${address.city}.`,type:'JOB_OPPORTUNITY',data:{jobId:data.booking.job?.id}});
  }
  res.status(201).json({data:data.booking});
});
apiRouter.get('/technician/jobs',allow('TECHNICIAN'),async(req:AuthRequest,res)=>{const tech=await db.technician.findFirst({where:{userId:req.identity!.userId,businessId:req.identity!.businessId,verificationStatus:'APPROVED'}});if(!tech)throw new AppError(403,'Approved technician profile required','TECHNICIAN_NOT_APPROVED');const data=await db.job.findMany({where:{booking:{businessId:req.identity!.businessId},assignments:{some:{technicianId:tech.id,unassignedAt:null}}},include:{booking:{include:{customer:{include:{user:true}},service:true,address:true}},history:true}});res.json({data});});
async function transition(req:AuthRequest,action:'accept'|'en-route'|'start'|'pause'|'resume'){
  const config={
    accept:{status:'ACCEPTED',from:['PENDING','ASSIGNED']},
    'en-route':{status:'EN_ROUTE',from:['ACCEPTED']},
    start:{status:'IN_PROGRESS',from:['ACCEPTED','EN_ROUTE']},
    pause:{status:'PAUSED',from:['IN_PROGRESS']},
    resume:{status:'IN_PROGRESS',from:['PAUSED']},
  }as const;
  const next=config[action];
  const tech=await db.technician.findFirst({where:{userId:req.identity!.userId,businessId:req.identity!.businessId,verificationStatus:'APPROVED'}});
  const job=tech&&await db.job.findFirst({where:{id:req.params.id,status:{in:[...next.from] as any},booking:{businessId:req.identity!.businessId},assignments:{some:{technicianId:tech.id,unassignedAt:null}}},include:{booking:{include:{customer:true}}}});
  if(!job)throw new AppError(409,'Job transition is not allowed','INVALID_JOB_TRANSITION');
  return db.$transaction(async tx=>{
    const updated=await tx.job.update({where:{id:job.id},data:{status:next.status,startedAt:next.status==='IN_PROGRESS'&&!job.startedAt?new Date():undefined}});
    if(next.status==='IN_PROGRESS')await tx.booking.update({where:{id:job.bookingId},data:{status:'IN_PROGRESS'}});
    await tx.jobStatusHistory.create({data:{jobId:job.id,status:next.status,note:`TECHNICIAN_${action.toUpperCase().replaceAll('-','_')}`,changedById:req.identity!.userId}});
    await tx.notification.create({data:{userId:job.booking.customer.userId,title:'Job status updated',body:`Your service job is now ${next.status.toLowerCase().replaceAll('_',' ')}.`,type:'JOB_STATUS'}});
    return updated;
  });
}
for(const action of['accept','en-route','start','pause','resume']as const)apiRouter.post(`/technician/jobs/:id/${action}`,allow('TECHNICIAN'),async(req:AuthRequest,res)=>res.json({data:await transition(req,action)}));
apiRouter.post('/technician/jobs/:id/reject',allow('TECHNICIAN'),async(req:AuthRequest,res)=>{const reason=z.object({reason:z.string().max(500).optional()}).parse(req.body??{}).reason;const tech=await db.technician.findFirst({where:{userId:req.identity!.userId,businessId:req.identity!.businessId,verificationStatus:'APPROVED'}});const job=tech&&await db.job.findFirst({where:{id:req.params.id,status:{in:['PENDING','ASSIGNED']},booking:{businessId:req.identity!.businessId},assignments:{some:{technicianId:tech.id,unassignedAt:null}}}});if(!job)throw new AppError(409,'Job rejection is not allowed','INVALID_JOB_TRANSITION');const data=await db.$transaction(async tx=>{await tx.jobAssignment.updateMany({where:{jobId:job.id,technicianId:tech!.id,unassignedAt:null},data:{unassignedAt:new Date()}});const updated=await tx.job.update({where:{id:job.id},data:{status:'PENDING'}});await tx.jobStatusHistory.create({data:{jobId:job.id,status:'PENDING',note:`TECHNICIAN_REJECTED${reason?`: ${reason}`:''}`,changedById:req.identity!.userId}});await tx.auditLog.create({data:{businessId:req.identity!.businessId,actorId:req.identity!.userId,action:'TECHNICIAN_REJECTED_JOB',entity:'Job',entityId:job.id,metadata:{reason}}});return updated;});res.json({data,status:'REASSIGNMENT_PENDING'});});
// Work completion is a two-party operation. A technician submits evidence and
// a report; only the booking owner may approve it. The old direct `/complete`
// transition remains for compatibility but must not be used by new clients.
apiRouter.post('/technician/jobs/:id/work-report',allow('TECHNICIAN'),async(req:AuthRequest,res)=>{const input=z.object({description:z.string().min(10).max(5000),summary:z.string().max(1000).optional(),additionalCharge:z.coerce.number().min(0).optional()}).parse(req.body);const tech=await db.technician.findFirst({where:{userId:req.identity!.userId,businessId:req.identity!.businessId}});const job=tech&&await db.job.findFirst({where:{id:req.params.id,booking:{businessId:req.identity!.businessId},assignments:{some:{technicianId:tech.id,unassignedAt:null}},status:{in:['ACCEPTED','IN_PROGRESS','PAUSED']}},include:{booking:{include:{customer:{include:{user:true}}}}}});if(!job)throw new AppError(409,'Only an active assigned job can have a work report','INVALID_JOB_STATE');if((input.additionalCharge??0)>0)throw new AppError(422,'Additional charges require a customer-approved quotation','QUOTE_APPROVAL_REQUIRED');const report=await db.$transaction(async tx=>{const data=await tx.workReport.upsert({where:{jobId:job.id},create:{jobId:job.id,technicianId:tech!.id,description:input.description,summary:input.summary,additionalCharge:input.additionalCharge??0,submittedAt:new Date()},update:{description:input.description,summary:input.summary,additionalCharge:input.additionalCharge??0,submittedAt:new Date()}});await tx.jobStatusHistory.create({data:{jobId:job.id,status:job.status,note:'WORK_REPORT_SUBMITTED_CUSTOMER_CONFIRMATION_PENDING',changedById:req.identity!.userId}});await tx.notification.create({data:{userId:job.booking.customer.userId,title:'Work report ready',body:'Review the completed work report before approving service completion.',type:'WORK_REPORT'}});await tx.auditLog.create({data:{businessId:req.identity!.businessId,actorId:req.identity!.userId,action:'WORK_REPORT_SUBMITTED',entity:'Job',entityId:job.id}});return data;});res.status(201).json({data:report,status:'CUSTOMER_CONFIRMATION_PENDING'});});
apiRouter.post('/customer/jobs/:id/approve-report',allow('CUSTOMER'),async(req:AuthRequest,res)=>{
  const customer=await db.customer.findFirst({where:{userId:req.identity!.userId,businessId:req.identity!.businessId}});
  const job=customer&&await db.job.findFirst({where:{id:req.params.id,booking:{businessId:req.identity!.businessId,customerId:customer.id},report:{is:{submittedAt:{not:null}}}},include:{booking:{include:{invoice:{include:{payments:{include:{refunds:{where:{status:'SUCCEEDED'}}}}}}}},assignments:{where:{unassignedAt:null},include:{technician:{include:{user:true}}}}}});
  if(!job)throw new AppError(404,'Submitted work report not found for this customer','REPORT_NOT_FOUND');
  if(job.status==='COMPLETED')return void res.json({data:job,status:'PAYMENT_SETTLEMENT_PENDING',duplicate:true});
  const invoice=job.booking.invoice;
  const verifiedNet=invoice?.payments.reduce((total,payment)=>{
    if(!['PAID','REFUNDED'].includes(payment.status))return total;
    const refunded=payment.refunds.reduce((sum,refund)=>sum+Number(refund.amount),0);
    return total+Number(payment.amount)-refunded;
  },0)??0;
  if(!invoice||verifiedNet+0.000001<Number(invoice.total))throw new AppError(409,'Full payment is pending server-side verification','PAYMENT_NOT_VERIFIED');
  if(job.assignments.length!==1)throw new AppError(409,'Job must have one active technician assignment','ASSIGNMENT_INVALID');
  const data=await db.$transaction(async tx=>{
    const business=await tx.business.findUniqueOrThrow({where:{id:req.identity!.businessId},select:{commissionRate:true}});
    const gross=Number(invoice.total);
    const commission=gross*Number(business.commissionRate)/100;
    const updated=await tx.job.update({where:{id:job.id},data:{status:'COMPLETED',completedAt:new Date()}});
    await tx.booking.update({where:{id:job.bookingId},data:{status:'COMPLETED'}});
    await tx.technicianLedger.create({data:{businessId:req.identity!.businessId,technicianId:job.assignments[0].technicianId,jobId:job.id,grossAmount:gross,commissionAmount:commission,netAmount:gross-commission,status:'PENDING'}});
    await tx.jobStatusHistory.create({data:{jobId:job.id,status:'COMPLETED',note:'CUSTOMER_APPROVED_FULL_PAYMENT_VERIFIED',changedById:req.identity!.userId}});
    await tx.auditLog.create({data:{businessId:req.identity!.businessId,actorId:req.identity!.userId,action:'CUSTOMER_APPROVED_WORK_REPORT',entity:'Job',entityId:job.id,metadata:{gross,commission,verifiedNet}}});
    for(const assignment of job.assignments)await tx.notification.create({data:{userId:assignment.technician.userId,title:'Work approved',body:'Customer approved the report. Earnings are pending settlement.',type:'WORK_APPROVED'}});
    return updated;
  });
  res.json({data,status:'PAYMENT_SETTLEMENT_PENDING'});
});
apiRouter.post('/customer/jobs/:id/disputes',allow('CUSTOMER'),async(req:AuthRequest,res)=>{const input=z.object({subject:z.string().min(3).max(160),description:z.string().min(10).max(5000)}).parse(req.body);const customer=await db.customer.findFirst({where:{userId:req.identity!.userId,businessId:req.identity!.businessId}});const job=customer&&await db.job.findFirst({where:{id:req.params.id,booking:{businessId:req.identity!.businessId,customerId:customer.id},report:{is:{submittedAt:{not:null}}}}});if(!job)throw new AppError(404,'Submitted work report not found for this customer','REPORT_NOT_FOUND');const ticket=await db.$transaction(async tx=>{const created=await tx.supportTicket.create({data:{businessId:req.identity!.businessId,customerId:customer!.id,bookingId:job.bookingId,jobId:job.id,subject:input.subject,description:input.description,status:'OPEN',priority:'HIGH'}});await tx.jobStatusHistory.create({data:{jobId:job.id,status:job.status,note:'CUSTOMER_DISPUTE_OPENED',changedById:req.identity!.userId}});await tx.auditLog.create({data:{businessId:req.identity!.businessId,actorId:req.identity!.userId,action:'CUSTOMER_DISPUTE_OPENED',entity:'Job',entityId:job.id,metadata:{ticketId:created.id}}});return created;});res.status(201).json({data:ticket,status:'DISPUTED'});});
apiRouter.put('/technician/availability',allow('TECHNICIAN'),async(req:AuthRequest,res)=>{const available=z.object({available:z.boolean()}).parse(req.body).available;const tech=await db.technician.findFirst({where:{userId:req.identity!.userId,businessId:req.identity!.businessId}});if(!tech)throw new AppError(403,'Technician profile required');if(available&&tech.verificationStatus!=='APPROVED')throw new AppError(403,'Only approved technicians can go online','TECHNICIAN_NOT_APPROVED');await db.technician.update({where:{id:tech.id},data:{available}});res.json({data:{available}});});
const locationInput=z.object({latitude:z.coerce.number().min(-90).max(90),longitude:z.coerce.number().min(-180).max(180),accuracy:z.coerce.number().min(0).max(10000).optional()});
async function activeAssignedJob(req:AuthRequest){const tech=await db.technician.findFirst({where:{userId:req.identity!.userId,businessId:req.identity!.businessId,verificationStatus:'APPROVED'}});const job=tech&&await db.job.findFirst({where:{id:req.params.id,booking:{businessId:req.identity!.businessId},assignments:{some:{technicianId:tech.id,unassignedAt:null}},status:{in:['ACCEPTED','EN_ROUTE','IN_PROGRESS']}},include:{booking:{include:{address:true}}}});if(!tech||!job)throw new AppError(403,'Location sharing is allowed only for an active assigned job','LOCATION_NOT_ALLOWED');return{tech,job};}
apiRouter.get('/technician/jobs/:id/customer-location',allow('TECHNICIAN'),async(req:AuthRequest,res)=>{const{job}=await activeAssignedJob(req);const address=job.booking.address;res.json({data:{addressId:address.id,line1:address.line1,line2:address.line2,city:address.city,state:address.state,postalCode:address.postalCode,latitude:address.latitude,longitude:address.longitude}});});
apiRouter.put('/technician/jobs/:id/location',allow('TECHNICIAN'),async(req:AuthRequest,res)=>{const input=locationInput.parse(req.body);const{tech,job}=await activeAssignedJob(req);await db.$transaction(async tx=>{await tx.technician.update({where:{id:tech.id},data:{locationLat:input.latitude,locationLng:input.longitude,locationAt:new Date(),locationConsent:true}});await tx.auditLog.create({data:{businessId:req.identity!.businessId,actorId:req.identity!.userId,action:'TECHNICIAN_LOCATION_UPDATED',entity:'Job',entityId:job.id,metadata:{accuracy:input.accuracy}}});});res.status(204).send();});
apiRouter.post('/technician/jobs/:id/stop-location-sharing',allow('TECHNICIAN'),async(req:AuthRequest,res)=>{const{tech,job}=await activeAssignedJob(req);await db.$transaction(async tx=>{await tx.technician.update({where:{id:tech.id},data:{locationConsent:false,locationLat:null,locationLng:null,locationAt:null}});await tx.auditLog.create({data:{businessId:req.identity!.businessId,actorId:req.identity!.userId,action:'TECHNICIAN_LOCATION_SHARING_STOPPED',entity:'Job',entityId:job.id}});});res.status(204).send();});
apiRouter.get('/technician/earnings',allow('TECHNICIAN'),async(req:AuthRequest,res)=>{const tech=await db.technician.findFirst({where:{userId:req.identity!.userId,businessId:req.identity!.businessId}});if(!tech)throw new AppError(403,'Technician profile required');const entries=await db.technicianLedger.findMany({where:{businessId:req.identity!.businessId,technicianId:tech.id},orderBy:{createdAt:'desc'}});res.json({data:entries});});
apiRouter.get('/admin/dashboard',allow('ADMIN','MANAGER','SUPER_ADMIN'),async(req:AuthRequest,res)=>{
  const businessId=req.identity!.businessId;
  const[totalCustomers,totalTechnicians,verifiedTechnicians,pendingTechnicianApprovals,totalBookings,activeJobs,completedJobs,cancelledBookings,revenuePayments,pendingPayments,pendingPayouts,pendingComplaints,recentBookings,recentPayments]=await db.$transaction([
    db.customer.count({where:{businessId}}),
    db.technician.count({where:{businessId}}),
    db.technician.count({where:{businessId,verificationStatus:'APPROVED'}}),
    db.technician.count({where:{businessId,verificationStatus:{in:['PENDING_VERIFICATION','UNDER_REVIEW']}}}),
    db.booking.count({where:{businessId,deletedAt:null}}),
    db.job.count({where:{booking:{businessId},status:{in:['ASSIGNED','ACCEPTED','EN_ROUTE','IN_PROGRESS','PAUSED']}}}),
    db.job.count({where:{booking:{businessId},status:'COMPLETED'}}),
    db.booking.count({where:{businessId,status:'CANCELLED',deletedAt:null}}),
    db.payment.findMany({where:{invoice:{businessId},status:{in:['PAID','REFUNDED']}},select:{amount:true,refunds:{where:{status:'SUCCEEDED'},select:{amount:true}}}}),
    db.payment.aggregate({_sum:{amount:true},where:{invoice:{businessId},status:{in:['PENDING','AUTHORIZED']}}}),
    db.payoutRequest.count({where:{businessId,status:{in:['REQUESTED','APPROVED','PROCESSING']}}}),
    db.supportTicket.count({where:{businessId,status:{not:'RESOLVED'}}}),
    db.booking.findMany({where:{businessId,deletedAt:null},orderBy:{createdAt:'desc'},take:5,include:{customer:{include:{user:true}},service:true}}),
    db.payment.findMany({where:{invoice:{businessId}},orderBy:{createdAt:'desc'},take:5,include:{invoice:true}}),
  ]);
  const totalRevenue=revenuePayments.reduce((total,payment)=>total+Number(payment.amount)-payment.refunds.reduce((refundTotal,refund)=>refundTotal+Number(refund.amount),0),0);
  res.json({data:{totalCustomers,totalTechnicians,verifiedTechnicians,pendingTechnicianApprovals,totalBookings,activeJobs,completedJobs,cancelledBookings,totalRevenue,pendingPayments:pendingPayments._sum.amount??0,pendingPayouts,pendingComplaints,recentBookings:recentBookings.map(x=>({id:x.id,customer:x.customer.user.name,service:x.service.name,status:x.status,amount:x.finalPrice??x.estimatedPrice,createdAt:x.createdAt})),recentTransactions:recentPayments.map(x=>({id:x.id,invoiceNumber:x.invoice.number,amount:x.amount,status:x.status,createdAt:x.createdAt}))}});
});
apiRouter.get('/admin/technicians',allow('ADMIN','MANAGER','SUPER_ADMIN'),async(req:AuthRequest,res)=>{
  const input=page.extend({q:z.string().trim().max(120).optional(),status:z.enum(['DRAFT','PENDING_VERIFICATION','UNDER_REVIEW','APPROVED','REJECTED','SUSPENDED','INACTIVE']).optional()}).parse(req.query);
  const where={businessId:req.identity!.businessId,...(input.status?{verificationStatus:input.status}:{}),...(input.q?{OR:[{user:{name:{contains:input.q,mode:'insensitive' as const}}},{user:{email:{contains:input.q,mode:'insensitive' as const}}},{skills:{has:input.q}}]}:{})};
  const[data,total]=await db.$transaction([
    db.technician.findMany({where,skip:(input.page-1)*input.limit,take:input.limit,orderBy:{user:{name:'asc'}},include:{user:{select:{id:true,name:true,email:true,phone:true,status:true}},documents:{select:{id:true,type:true,status:true,rejectionReason:true,uploadedAt:true,reviewedAt:true}},serviceAreas:{where:{active:true},include:{serviceArea:true}}}}),
    db.technician.count({where}),
  ]);
  res.json({data,meta:{page:input.page,limit:input.limit,total}});
});
apiRouter.patch('/admin/technicians/:id/documents/:documentId',allow('ADMIN','MANAGER','SUPER_ADMIN'),async(req:AuthRequest,res)=>{const input=z.object({status:z.enum(['APPROVED','REJECTED']),reason:z.string().max(1000).optional()}).parse(req.body);if(input.status==='REJECTED'&&!input.reason)throw new AppError(422,'Rejection reason is required','REASON_REQUIRED');const document=await db.technicianDocument.findFirst({where:{id:req.params.documentId,technicianId:req.params.id,technician:{businessId:req.identity!.businessId}}});if(!document)throw new AppError(404,'Technician document not found');const data=await db.$transaction(async tx=>{const updated=await tx.technicianDocument.update({where:{id:document.id},data:{status:input.status,rejectionReason:input.status==='REJECTED'?input.reason:null,reviewedAt:new Date(),reviewedById:req.identity!.userId}});await tx.auditLog.create({data:{businessId:req.identity!.businessId,actorId:req.identity!.userId,action:`TECHNICIAN_DOCUMENT_${input.status}`,entity:'TechnicianDocument',entityId:document.id,metadata:{reason:input.reason}}});return updated;});res.json({data});});
apiRouter.patch('/admin/technicians/:id/verification',allow('ADMIN','MANAGER','SUPER_ADMIN'),async(req:AuthRequest,res)=>{const input=z.object({status:z.enum(['UNDER_REVIEW','APPROVED','REJECTED','SUSPENDED','INACTIVE']),reason:z.string().max(1000).optional()}).parse(req.body);if(['REJECTED','SUSPENDED'].includes(input.status)&&!input.reason)throw new AppError(422,'A reason is required','REASON_REQUIRED');const technician=await db.technician.findFirst({where:{id:req.params.id,businessId:req.identity!.businessId},include:{documents:true,user:true}});if(!technician)throw new AppError(404,'Technician not found');const requiredDocumentsApproved=requiredTechnicianDocuments.every(type=>technician.documents.some(document=>document.type===type&&document.status==='APPROVED'));if(input.status==='APPROVED'&&(!technician.profileCompletedAt||!technician.aadhaarConsentAt||!requiredDocumentsApproved))throw new AppError(409,'The completed profile and all required eKYC documents must be approved first','DOCUMENTS_NOT_APPROVED');const data=await db.$transaction(async tx=>{const updated=await tx.technician.update({where:{id:technician.id},data:{verificationStatus:input.status,available:input.status==='APPROVED'?technician.available:false}});await tx.notification.create({data:{userId:technician.userId,title:'Verification status updated',body:`Your technician profile is now ${input.status.toLowerCase().replaceAll('_',' ')}.`,type:'TECHNICIAN_VERIFICATION'}});await tx.auditLog.create({data:{businessId:req.identity!.businessId,actorId:req.identity!.userId,action:`TECHNICIAN_VERIFICATION_${input.status}`,entity:'Technician',entityId:technician.id,metadata:{previousStatus:technician.verificationStatus,reason:input.reason}}});return updated;});res.json({data});});
apiRouter.get('/admin/customers',allow('ADMIN','MANAGER','SUPER_ADMIN'),async(req:AuthRequest,res)=>{const input=page.extend({q:z.string().max(120).optional(),status:z.enum(['ACTIVE','SUSPENDED','INVITED']).optional()}).parse(req.query);const where={businessId:req.identity!.businessId,...(input.status?{user:{status:input.status}}:{}),...(input.q?{OR:[{user:{name:{contains:input.q,mode:'insensitive' as const}}},{user:{email:{contains:input.q,mode:'insensitive' as const}}},{user:{phone:{contains:input.q}}}]}:{})};const[data,total]=await db.$transaction([db.customer.findMany({where,skip:(input.page-1)*input.limit,take:input.limit,orderBy:{user:{name:'asc'}},include:{user:{select:{id:true,name:true,email:true,phone:true,status:true,createdAt:true}},_count:{select:{addresses:true,bookings:true,supportTickets:true}}}}),db.customer.count({where})]);res.json({data,meta:{page:input.page,limit:input.limit,total}});});
apiRouter.patch('/admin/customers/:id/status',allow('ADMIN','MANAGER','SUPER_ADMIN'),async(req:AuthRequest,res)=>{const input=z.object({status:z.enum(['ACTIVE','SUSPENDED']),reason:z.string().max(1000).optional()}).parse(req.body);if(input.status==='SUSPENDED'&&!input.reason)throw new AppError(422,'Suspension reason is required','REASON_REQUIRED');const customer=await db.customer.findFirst({where:{id:req.params.id,businessId:req.identity!.businessId},include:{user:true}});if(!customer)throw new AppError(404,'Customer not found');const data=await db.$transaction(async tx=>{const user=await tx.user.update({where:{id:customer.userId},data:{status:input.status}});if(input.status==='SUSPENDED')await tx.refreshSession.updateMany({where:{userId:customer.userId,revokedAt:null},data:{revokedAt:new Date()}});await tx.auditLog.create({data:{businessId:req.identity!.businessId,actorId:req.identity!.userId,action:`CUSTOMER_${input.status}`,entity:'Customer',entityId:customer.id,metadata:{previousStatus:customer.user.status,reason:input.reason}}});return user;});res.json({data});});
apiRouter.get('/admin/jobs',allow('ADMIN','MANAGER','SUPER_ADMIN'),async(req:AuthRequest,res)=>res.json({data:await db.job.findMany({where:{booking:{businessId:req.identity!.businessId}},include:{booking:{include:{customer:{include:{user:true}},service:true}},assignments:{include:{technician:{include:{user:true}}}}}})}));
apiRouter.post('/admin/jobs/:id/assign-technician',allow('ADMIN','MANAGER','SUPER_ADMIN'),async(req:AuthRequest,res)=>{
  const jobId=z.string().uuid().parse(req.params.id);
  const technicianId=z.object({technicianId:z.string().uuid()}).parse(req.body).technicianId;
  const data=await db.$transaction(async tx=>{
    await tx.$queryRaw`SELECT "id" FROM "Job" WHERE "id" = ${jobId} FOR UPDATE`;
    await tx.$queryRaw`SELECT "id" FROM "Technician" WHERE "id" = ${technicianId} FOR UPDATE`;
    const job=await tx.job.findFirst({where:{id:jobId,status:{in:['PENDING','ASSIGNED']},booking:{businessId:req.identity!.businessId}},include:{booking:{include:{service:true,address:true}},assignments:{where:{unassignedAt:null},include:{technician:{include:{user:true}}}}}});
    if(!job)throw new AppError(409,'Job is not eligible for assignment','JOB_NOT_ASSIGNABLE');
    const alreadyAssigned=job.assignments.find(assignment=>assignment.technicianId===technicianId);
    if(alreadyAssigned)return{assignment:alreadyAssigned,duplicate:true};
    const technician=await tx.technician.findFirst({where:{id:technicianId,businessId:req.identity!.businessId,verificationStatus:'APPROVED',available:true},include:{user:true,serviceAreas:{where:{active:true},include:{serviceArea:true}}}});
    if(!technician)throw new AppError(422,'Technician must be approved and online','TECHNICIAN_NOT_ELIGIBLE');
    const technicianSkills=new Set(technician.skills.map(skill=>skill.trim().toLowerCase()));
    const missingSkills=job.booking.service.requiredSkills.filter(skill=>!technicianSkills.has(skill.trim().toLowerCase()));
    if(missingSkills.length>0)throw new AppError(422,`Technician is missing required skills: ${missingSkills.join(', ')}`,'TECHNICIAN_SKILL_MISMATCH');
    if(technician.serviceAreas.length===0)throw new AppError(422,'Configure at least one service area for this technician','TECHNICIAN_AREA_NOT_CONFIGURED');
    const areaEligible=technician.serviceAreas.some(item=>item.serviceArea.active&&item.serviceArea.postalCodes.includes(job.booking.address.postalCode));
    if(!areaEligible)throw new AppError(422,'Technician does not serve the job address','TECHNICIAN_AREA_MISMATCH');
    const activeAssignments=await tx.jobAssignment.findMany({where:{technicianId,unassignedAt:null,jobId:{not:job.id},job:{status:{in:['ASSIGNED','ACCEPTED','EN_ROUTE','IN_PROGRESS','PAUSED']},booking:{businessId:req.identity!.businessId}}},include:{job:{include:{booking:{include:{service:true}}}}}});
    const targetStart=job.booking.scheduledAt.getTime();
    const targetEnd=targetStart+job.booking.service.durationMinutes*60_000;
    const scheduleConflict=activeAssignments.some(item=>{const otherStart=item.job.booking.scheduledAt.getTime();const otherEnd=otherStart+item.job.booking.service.durationMinutes*60_000;return targetStart<otherEnd&&otherStart<targetEnd;});
    if(scheduleConflict)throw new AppError(409,'Technician has an overlapping active job','TECHNICIAN_SCHEDULE_CONFLICT');
    const previous=job.assignments.map(assignment=>({technicianId:assignment.technicianId,userId:assignment.technician.userId}));
    await tx.jobAssignment.updateMany({where:{jobId:job.id,unassignedAt:null},data:{unassignedAt:new Date()}});
    const assignment=await tx.jobAssignment.create({data:{jobId:job.id,technicianId}});
    await tx.job.update({where:{id:job.id},data:{status:'ASSIGNED'}});
    await tx.booking.update({where:{id:job.bookingId},data:{status:'ASSIGNED'}});
    await tx.jobStatusHistory.create({data:{jobId:job.id,status:'ASSIGNED',note:previous.length>0?'ADMIN_REASSIGNED':'ADMIN_ASSIGNED',changedById:req.identity!.userId}});
    await tx.notification.create({data:{userId:technician.userId,title:'New job assigned',body:'A new service job has been assigned to you.',type:'JOB_ASSIGNED'}});
    for(const old of previous)if(old.technicianId!==technicianId)await tx.notification.create({data:{userId:old.userId,title:'Job reassigned',body:'A previously assigned job has been reassigned by operations.',type:'JOB_REASSIGNED'}});
    await tx.auditLog.create({data:{businessId:req.identity!.businessId,actorId:req.identity!.userId,action:previous.length>0?'JOB_REASSIGNED':'JOB_ASSIGNED',entity:'Job',entityId:job.id,metadata:{technicianId,previousTechnicianIds:previous.map(item=>item.technicianId)}}});
    return{assignment,duplicate:false};
  },{isolationLevel:'Serializable'});
  res.status(data.duplicate?200:201).json({data:data.assignment,duplicate:data.duplicate});
});
apiRouter.get('/invoices',async(req:AuthRequest,res)=>{const elevated=['ADMIN','MANAGER','SUPER_ADMIN'].includes(req.identity!.role);const where=elevated?{businessId:req.identity!.businessId}:{businessId:req.identity!.businessId,booking:{customer:{userId:req.identity!.userId}}};res.json({data:await db.invoice.findMany({where,include:{items:true,payments:true}})});});
apiRouter.post('/payments/create-order',(_req,_res)=>{throw new AppError(501,'Payment provider is not configured','PAYMENT_NOT_CONFIGURED');});apiRouter.post('/payments/verify',(_req,_res)=>{throw new AppError(501,'Payment verification is not configured','PAYMENT_NOT_CONFIGURED');});
apiRouter.use(technicianOnboardingRouter);apiRouter.use('/admin',adminRouter);apiRouter.use('/admin/analytics',adminAnalyticsRouter);apiRouter.use(financeRouter);
