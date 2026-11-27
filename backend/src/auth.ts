import{Router}from'express';import{z}from'zod';import{db}from'./db.js';import{AppError}from'./errors.js';import{hashPassword,hashToken,signAccess,signRefresh,verifyPassword,verifyRefresh}from'./security.js';import{authenticate}from'./middleware.js';import type{AuthRequest}from'./types.js';
export const authRouter=Router();const credentials=z.object({email:z.string().email(),password:z.string().min(8),businessId:z.string().uuid().optional()});
// Public registration is deliberately customer-only. Administrative access is
// provisioned through a trusted business workflow, never from a client role.
authRouter.post('/register',async(req,res)=>{const body=credentials.extend({name:z.string().min(2),phone:z.string().min(6).optional(),businessName:z.string().min(2)}).parse(req.body);if(await db.user.findUnique({where:{email:body.email}}))throw new AppError(409,'Email already registered','EMAIL_EXISTS');const passwordHash=await hashPassword(body.password);const result=await db.$transaction(async tx=>{const business=await tx.business.create({data:{name:body.businessName,slug:`${body.businessName.toLowerCase().replace(/[^a-z0-9]+/g,'-')}-${Date.now()}`}});const role=await tx.role.upsert({where:{name:'CUSTOMER'},update:{},create:{name:'CUSTOMER'}});const user=await tx.user.create({data:{email:body.email,passwordHash,name:body.name,phone:body.phone}});await tx.businessMember.create({data:{businessId:business.id,userId:user.id,roleId:role.id}});await tx.customer.create({data:{businessId:business.id,userId:user.id}});return{user,business};});res.status(201).json({data:{id:result.user.id,email:result.user.email,businessId:result.business.id,role:'CUSTOMER'}});});
authRouter.post('/register/technician',async(req,res)=>{
  const body=credentials.extend({
    businessId:z.string().uuid(),
    name:z.string().trim().min(2).max(120),
    phone:z.string().trim().min(6).max(30),
    skills:z.array(z.string().trim().min(1).max(80)).max(50).default([]),
    experienceYears:z.coerce.number().int().min(0).max(80).default(0),
  }).parse(req.body);
  if(await db.user.findUnique({where:{email:body.email}}))throw new AppError(409,'Email already registered','EMAIL_EXISTS');
  const business=await db.business.findFirst({where:{id:body.businessId,deletedAt:null}});
  if(!business)throw new AppError(422,'Business is not accepting this application','INVALID_BUSINESS');
  const passwordHash=await hashPassword(body.password);
  const result=await db.$transaction(async tx=>{
    const role=await tx.role.upsert({where:{name:'TECHNICIAN'},update:{},create:{name:'TECHNICIAN'}});
    const user=await tx.user.create({data:{email:body.email,passwordHash,name:body.name,phone:body.phone}});
    await tx.businessMember.create({data:{businessId:business.id,userId:user.id,roleId:role.id}});
    const technician=await tx.technician.create({data:{businessId:business.id,userId:user.id,skills:[...new Set(body.skills)],experienceYears:body.experienceYears,verificationStatus:'DRAFT',available:false}});
    await tx.auditLog.create({data:{businessId:business.id,actorId:user.id,action:'TECHNICIAN_APPLICATION_CREATED',entity:'Technician',entityId:technician.id}});
    return{user,technician};
  });
  res.status(201).json({data:{id:result.user.id,email:result.user.email,businessId:business.id,role:'TECHNICIAN',technicianId:result.technician.id,verificationStatus:result.technician.verificationStatus,nextStep:'UPLOAD_REQUIRED_DOCUMENTS'}});
});
authRouter.post('/login',async(req,res)=>{const body=credentials.parse(req.body);const user=await db.user.findUnique({where:{email:body.email},include:{memberships:{include:{role:{include:{permissions:{include:{permission:true}}}},business:true}}}});if(!user||!await verifyPassword(body.password,user.passwordHash))throw new AppError(401,'Invalid email or password','INVALID_CREDENTIALS');if(user.status!=='ACTIVE'||user.deletedAt)throw new AppError(403,'This account is not active','ACCOUNT_INACTIVE');const membership=user.memberships.find(x=>x.active&&(!body.businessId||x.businessId===body.businessId));if(!membership)throw new AppError(403,'No active access to this business','TENANT_FORBIDDEN');const identity={userId:user.id,businessId:membership.businessId,role:membership.role.name,permissions:membership.role.permissions.map(x=>x.permission.key)};const accessToken=signAccess(identity);const refreshToken=signRefresh(user.id,membership.businessId);await db.refreshSession.create({data:{userId:user.id,tokenHash:hashToken(refreshToken),expiresAt:new Date(Date.now()+86400000*30)}});res.json({data:{accessToken,refreshToken,user:{id:user.id,name:user.name,email:user.email,role:identity.role,businessId:identity.businessId}}});});
authRouter.post('/refresh-token',async(req,res)=>{
  const token=z.object({refreshToken:z.string()}).parse(req.body).refreshToken;
  const payload=verifyRefresh(token);
  const session=await db.refreshSession.findUnique({
    where:{tokenHash:hashToken(token)},
    include:{user:{include:{memberships:{include:{role:{include:{permissions:{include:{permission:true}}}}}}}}},
  });
  if(!session||session.revokedAt||session.expiresAt<new Date()||session.userId!==payload.sub)throw new AppError(401,'Refresh token invalid','INVALID_REFRESH');
  if(session.user.status!=='ACTIVE'||session.user.deletedAt)throw new AppError(403,'Account is not active','ACCOUNT_INACTIVE');
  const membership=session.user.memberships.find(x=>x.active&&x.businessId===payload.businessId);
  if(!membership)throw new AppError(403,'Active business membership missing');
  const next=signRefresh(session.userId,membership.businessId);
  await db.$transaction([db.refreshSession.update({where:{id:session.id},data:{revokedAt:new Date()}}),db.refreshSession.create({data:{userId:session.userId,tokenHash:hashToken(next),expiresAt:new Date(Date.now()+86400000*30)}})]);
  res.json({data:{accessToken:signAccess({userId:session.userId,businessId:membership.businessId,role:membership.role.name,permissions:membership.role.permissions.map(x=>x.permission.key)}),refreshToken:next}});
});
authRouter.post('/logout',async(req,res)=>{const token=z.object({refreshToken:z.string()}).parse(req.body).refreshToken;await db.refreshSession.updateMany({where:{tokenHash:hashToken(token),revokedAt:null},data:{revokedAt:new Date()}});res.status(204).send();});
authRouter.get('/me',authenticate,async(req:AuthRequest,res)=>{const user=await db.user.findUnique({where:{id:req.identity!.userId},select:{id:true,name:true,email:true,phone:true,status:true}});res.json({data:user});});
authRouter.post('/forgot-password',(_req,res)=>res.status(202).json({data:{message:'If the account exists, reset instructions will be sent.'}}));authRouter.post('/reset-password',(_req,_res)=>{throw new AppError(501,'Password reset provider not configured','NOT_CONFIGURED');});
