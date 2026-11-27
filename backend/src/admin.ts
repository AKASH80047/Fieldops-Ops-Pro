import { Router } from 'express';
import { z } from 'zod';
import { db } from './db.js';
import { AppError } from './errors.js';
import { allow } from './middleware.js';
import type { AuthRequest } from './types.js';

export const adminRouter = Router();
adminRouter.use(allow('ADMIN', 'MANAGER', 'SUPER_ADMIN'));

const page = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});
const identifier = z.string().uuid();
const nullableText = z.string().trim().max(2000).nullable().optional();
const queryBoolean = z.enum(['true', 'false']).transform((value) => value === 'true');

function tenant(req: AuthRequest) {
  return req.identity!.businessId;
}

async function audit(
  req: AuthRequest,
  action: string,
  entity: string,
  entityId: string,
  metadata?: Record<string, unknown>,
) {
  await db.auditLog.create({
    data: {
      businessId: tenant(req),
      actorId: req.identity!.userId,
      action,
      entity,
      entityId,
      metadata: metadata as never,
    },
  });
}

const categoryCreate = z.object({
  name: z.string().trim().min(2).max(120),
  description: nullableText,
  imageObjectKey: z.string().trim().min(3).max(500).nullable().optional(),
  displayOrder: z.coerce.number().int().min(0).max(10000).default(0),
  active: z.boolean().default(true),
});
const categoryPatch = categoryCreate.partial().refine(
  (value) => Object.keys(value).length > 0,
  'At least one field is required',
);

adminRouter.get('/service-categories', async (req: AuthRequest, res) => {
  const input = page.extend({
    q: z.string().trim().max(120).optional(),
    active: queryBoolean.optional(),
  }).parse(req.query);
  const where = {
    businessId: tenant(req),
    deletedAt: null,
    ...(input.active === undefined ? {} : { active: input.active }),
    ...(input.q
      ? { name: { contains: input.q, mode: 'insensitive' as const } }
      : {}),
  };
  const [data, total] = await db.$transaction([
    db.serviceCategory.findMany({
      where,
      skip: (input.page - 1) * input.limit,
      take: input.limit,
      orderBy: [{ displayOrder: 'asc' }, { name: 'asc' }],
      include: {
        _count: { select: { services: { where: { deletedAt: null } } } },
      },
    }),
    db.serviceCategory.count({ where }),
  ]);
  res.json({ data, meta: { page: input.page, limit: input.limit, total } });
});

adminRouter.post('/service-categories', async (req: AuthRequest, res) => {
  const input = categoryCreate.parse(req.body);
  const duplicate = await db.serviceCategory.findFirst({
    where: {
      businessId: tenant(req),
      deletedAt: null,
      name: { equals: input.name, mode: 'insensitive' },
    },
  });
  if (duplicate) {
    throw new AppError(409, 'A category with this name already exists', 'CATEGORY_EXISTS');
  }
  const data = await db.$transaction(async (tx) => {
    const created = await tx.serviceCategory.create({
      data: { businessId: tenant(req), ...input },
    });
    await tx.auditLog.create({
      data: {
        businessId: tenant(req),
        actorId: req.identity!.userId,
        action: 'SERVICE_CATEGORY_CREATED',
        entity: 'ServiceCategory',
        entityId: created.id,
      },
    });
    return created;
  });
  res.status(201).json({ data });
});

adminRouter.patch('/service-categories/:id', async (req: AuthRequest, res) => {
  const id = identifier.parse(req.params.id);
  const input = categoryPatch.parse(req.body);
  const category = await db.serviceCategory.findFirst({
    where: { id, businessId: tenant(req), deletedAt: null },
  });
  if (!category) throw new AppError(404, 'Service category not found');
  if (input.name) {
    const duplicate = await db.serviceCategory.findFirst({
      where: {
        businessId: tenant(req),
        deletedAt: null,
        id: { not: id },
        name: { equals: input.name, mode: 'insensitive' },
      },
    });
    if (duplicate) throw new AppError(409, 'A category with this name already exists', 'CATEGORY_EXISTS');
  }
  const data = await db.serviceCategory.update({ where: { id }, data: input });
  await audit(req, 'SERVICE_CATEGORY_UPDATED', 'ServiceCategory', id, {
    changedFields: Object.keys(input),
  });
  res.json({ data });
});

adminRouter.delete('/service-categories/:id', async (req: AuthRequest, res) => {
  const id = identifier.parse(req.params.id);
  const category = await db.serviceCategory.findFirst({
    where: { id, businessId: tenant(req), deletedAt: null },
  });
  if (!category) throw new AppError(404, 'Service category not found');
  const activeServices = await db.service.count({
    where: { businessId: tenant(req), categoryId: id, active: true, deletedAt: null },
  });
  if (activeServices > 0) {
    throw new AppError(
      409,
      'Disable or move active services before deleting this category',
      'CATEGORY_IN_USE',
    );
  }
  await db.$transaction(async (tx) => {
    await tx.serviceCategory.update({
      where: { id },
      data: { active: false, deletedAt: new Date() },
    });
    await tx.auditLog.create({
      data: {
        businessId: tenant(req),
        actorId: req.identity!.userId,
        action: 'SERVICE_CATEGORY_DELETED',
        entity: 'ServiceCategory',
        entityId: id,
      },
    });
  });
  res.status(204).send();
});

const serviceCreate = z.object({
  categoryId: z.string().uuid(),
  name: z.string().trim().min(2).max(160),
  description: z.string().trim().min(10).max(5000),
  imageObjectKey: z.string().trim().min(3).max(500).nullable().optional(),
  basePrice: z.coerce.number().min(0).max(100000000),
  durationMinutes: z.coerce.number().int().min(1).max(10080),
  taxRate: z.coerce.number().min(0).max(100).default(0),
  requiredSkills: z.array(z.string().trim().min(1).max(80)).max(50).default([]),
  serviceAreaIds: z.array(z.string().uuid()).max(250).default([]),
  active: z.boolean().default(true),
});
const servicePatch = serviceCreate.partial().refine(
  (value) => Object.keys(value).length > 0,
  'At least one field is required',
);

async function validateCatalogReferences(
  req: AuthRequest,
  categoryId?: string,
  serviceAreaIds?: string[],
) {
  if (categoryId) {
    const category = await db.serviceCategory.findFirst({
      where: {
        id: categoryId,
        businessId: tenant(req),
        deletedAt: null,
      },
    });
    if (!category) throw new AppError(422, 'Category is not valid for this business', 'INVALID_CATEGORY');
  }
  if (serviceAreaIds) {
    const uniqueIds = [...new Set(serviceAreaIds)];
    const count = await db.serviceArea.count({
      where: { id: { in: uniqueIds }, businessId: tenant(req) },
    });
    if (count !== uniqueIds.length) {
      throw new AppError(422, 'One or more service areas are invalid', 'INVALID_SERVICE_AREA');
    }
  }
}

adminRouter.get('/services', async (req: AuthRequest, res) => {
  const input = page.extend({
    q: z.string().trim().max(120).optional(),
    categoryId: z.string().uuid().optional(),
    active: queryBoolean.optional(),
  }).parse(req.query);
  const where = {
    businessId: tenant(req),
    deletedAt: null,
    ...(input.categoryId ? { categoryId: input.categoryId } : {}),
    ...(input.active === undefined ? {} : { active: input.active }),
    ...(input.q
      ? {
          OR: [
            { name: { contains: input.q, mode: 'insensitive' as const } },
            { description: { contains: input.q, mode: 'insensitive' as const } },
          ],
        }
      : {}),
  };
  const [data, total] = await db.$transaction([
    db.service.findMany({
      where,
      skip: (input.page - 1) * input.limit,
      take: input.limit,
      orderBy: { name: 'asc' },
      include: {
        category: true,
        coverage: { include: { serviceArea: true } },
      },
    }),
    db.service.count({ where }),
  ]);
  res.json({ data, meta: { page: input.page, limit: input.limit, total } });
});

adminRouter.post('/services', async (req: AuthRequest, res) => {
  const input = serviceCreate.parse(req.body);
  await validateCatalogReferences(req, input.categoryId, input.serviceAreaIds);
  const duplicate = await db.service.findFirst({
    where: {
      businessId: tenant(req),
      categoryId: input.categoryId,
      deletedAt: null,
      name: { equals: input.name, mode: 'insensitive' },
    },
  });
  if (duplicate) throw new AppError(409, 'This service already exists in the category', 'SERVICE_EXISTS');
  const { serviceAreaIds, ...service } = input;
  const data = await db.$transaction(async (tx) => {
    const created = await tx.service.create({
      data: {
        businessId: tenant(req),
        ...service,
        coverage: {
          create: [...new Set(serviceAreaIds)].map((serviceAreaId) => ({ serviceAreaId })),
        },
      },
      include: { category: true, coverage: { include: { serviceArea: true } } },
    });
    await tx.auditLog.create({
      data: {
        businessId: tenant(req),
        actorId: req.identity!.userId,
        action: 'SERVICE_CREATED',
        entity: 'Service',
        entityId: created.id,
      },
    });
    return created;
  });
  res.status(201).json({ data });
});

adminRouter.patch('/services/:id', async (req: AuthRequest, res) => {
  const id = identifier.parse(req.params.id);
  const input = servicePatch.parse(req.body);
  const current = await db.service.findFirst({
    where: { id, businessId: tenant(req), deletedAt: null },
  });
  if (!current) throw new AppError(404, 'Service not found');
  await validateCatalogReferences(req, input.categoryId, input.serviceAreaIds);
  if (input.name || input.categoryId) {
    const duplicate = await db.service.findFirst({
      where: {
        businessId: tenant(req),
        categoryId: input.categoryId ?? current.categoryId,
        deletedAt: null,
        id: { not: id },
        name: { equals: input.name ?? current.name, mode: 'insensitive' },
      },
    });
    if (duplicate) throw new AppError(409, 'This service already exists in the category', 'SERVICE_EXISTS');
  }
  const { serviceAreaIds, ...service } = input;
  const data = await db.$transaction(async (tx) => {
    const updated = await tx.service.update({
      where: { id },
      data: {
        ...service,
        ...(serviceAreaIds
          ? {
              coverage: {
                deleteMany: {},
                create: [...new Set(serviceAreaIds)].map((serviceAreaId) => ({ serviceAreaId })),
              },
            }
          : {}),
      },
      include: { category: true, coverage: { include: { serviceArea: true } } },
    });
    await tx.auditLog.create({
      data: {
        businessId: tenant(req),
        actorId: req.identity!.userId,
        action: 'SERVICE_UPDATED',
        entity: 'Service',
        entityId: id,
        metadata: { changedFields: Object.keys(input) },
      },
    });
    return updated;
  });
  res.json({ data });
});

adminRouter.delete('/services/:id', async (req: AuthRequest, res) => {
  const id = identifier.parse(req.params.id);
  const service = await db.service.findFirst({
    where: { id, businessId: tenant(req), deletedAt: null },
  });
  if (!service) throw new AppError(404, 'Service not found');
  await db.$transaction(async (tx) => {
    await tx.service.update({
      where: { id },
      data: { active: false, deletedAt: new Date() },
    });
    await tx.auditLog.create({
      data: {
        businessId: tenant(req),
        actorId: req.identity!.userId,
        action: 'SERVICE_DELETED',
        entity: 'Service',
        entityId: id,
      },
    });
  });
  res.status(204).send();
});

const areaCreate = z.object({
  name: z.string().trim().min(2).max(120),
  postalCodes: z.array(z.string().trim().min(3).max(20)).min(1).max(500),
  active: z.boolean().default(true),
});
const areaPatch = areaCreate.partial().refine(
  (value) => Object.keys(value).length > 0,
  'At least one field is required',
);

adminRouter.get('/service-areas', async (req: AuthRequest, res) => {
  const data = await db.serviceArea.findMany({
    where: { businessId: tenant(req) },
    orderBy: { name: 'asc' },
  });
  res.json({ data });
});

adminRouter.post('/service-areas', async (req: AuthRequest, res) => {
  const input = areaCreate.parse(req.body);
  const data = await db.serviceArea.create({
    data: {
      businessId: tenant(req),
      ...input,
      postalCodes: [...new Set(input.postalCodes)],
    },
  });
  await audit(req, 'SERVICE_AREA_CREATED', 'ServiceArea', data.id);
  res.status(201).json({ data });
});

adminRouter.patch('/service-areas/:id', async (req: AuthRequest, res) => {
  const id = identifier.parse(req.params.id);
  const input = areaPatch.parse(req.body);
  const area = await db.serviceArea.findFirst({
    where: { id, businessId: tenant(req) },
  });
  if (!area) throw new AppError(404, 'Service area not found');
  const data = await db.serviceArea.update({
    where: { id },
    data: {
      ...input,
      ...(input.postalCodes ? { postalCodes: [...new Set(input.postalCodes)] } : {}),
    },
  });
  await audit(req, 'SERVICE_AREA_UPDATED', 'ServiceArea', id, {
    changedFields: Object.keys(input),
  });
  res.json({ data });
});

adminRouter.delete('/service-areas/:id', async (req: AuthRequest, res) => {
  const id = identifier.parse(req.params.id);
  const area = await db.serviceArea.findFirst({
    where: { id, businessId: tenant(req) },
  });
  if (!area) throw new AppError(404, 'Service area not found');
  const assignments = await db.serviceAreaAssignment.count({ where: { serviceAreaId: id } });
  if (assignments > 0) {
    throw new AppError(409, 'Disable the service area because it is assigned to services', 'AREA_IN_USE');
  }
  await db.serviceArea.delete({ where: { id } });
  await audit(req, 'SERVICE_AREA_DELETED', 'ServiceArea', id);
  res.status(204).send();
});

adminRouter.patch('/technicians/:id/profile', async (req: AuthRequest, res) => {
  const id = identifier.parse(req.params.id);
  const input = z.object({
    skills: z.array(z.string().trim().min(1).max(80)).max(50).optional(),
    experienceYears: z.coerce.number().int().min(0).max(80).optional(),
    serviceAreaIds: z.array(z.string().uuid()).max(250).optional(),
  }).refine((value) => Object.keys(value).length > 0, 'At least one field is required').parse(req.body);
  const technician = await db.technician.findFirst({
    where: { id, businessId: tenant(req) },
  });
  if (!technician) throw new AppError(404, 'Technician not found');
  if (input.serviceAreaIds) {
    const uniqueIds = [...new Set(input.serviceAreaIds)];
    const count = await db.serviceArea.count({
      where: { id: { in: uniqueIds }, businessId: tenant(req), active: true },
    });
    if (count !== uniqueIds.length) {
      throw new AppError(422, 'One or more technician service areas are invalid', 'INVALID_SERVICE_AREA');
    }
  }
  const { serviceAreaIds, ...profile } = input;
  const data = await db.$transaction(async (tx) => {
    const updated = await tx.technician.update({
      where: { id },
      data: {
        ...profile,
        ...(serviceAreaIds
          ? {
              serviceAreas: {
                deleteMany: {},
                create: [...new Set(serviceAreaIds)].map((serviceAreaId) => ({ serviceAreaId })),
              },
            }
          : {}),
      },
      include: { serviceAreas: { include: { serviceArea: true } } },
    });
    await tx.auditLog.create({
      data: {
        businessId: tenant(req),
        actorId: req.identity!.userId,
        action: 'TECHNICIAN_PROFILE_UPDATED',
        entity: 'Technician',
        entityId: id,
        metadata: { changedFields: Object.keys(input) },
      },
    });
    return updated;
  });
  res.json({ data });
});

adminRouter.patch('/jobs/:id/status', async (req: AuthRequest, res) => {
  const id = identifier.parse(req.params.id);
  const input = z.object({
    status: z.enum(['PENDING', 'CANCELLED']),
    reason: z.string().trim().min(5).max(1000),
  }).parse(req.body);
  const job = await db.job.findFirst({
    where: { id, booking: { businessId: tenant(req) } },
    include: {
      booking: { include: { customer: true } },
      assignments: {
        where: { unassignedAt: null },
        include: { technician: true },
      },
    },
  });
  if (!job) throw new AppError(404, 'Job not found');
  const allowed = input.status === 'PENDING'
    ? ['ASSIGNED']
    : ['PENDING', 'ASSIGNED', 'ACCEPTED'];
  if (!allowed.includes(job.status)) {
    throw new AppError(409, `Job cannot move from ${job.status} to ${input.status}`, 'INVALID_JOB_TRANSITION');
  }
  const data = await db.$transaction(async (tx) => {
    await tx.jobAssignment.updateMany({
      where: { jobId: id, unassignedAt: null },
      data: { unassignedAt: new Date() },
    });
    const updated = await tx.job.update({ where: { id }, data: { status: input.status } });
    await tx.booking.update({
      where: { id: job.bookingId },
      data: {
        status: input.status,
        cancelledReason: input.status === 'CANCELLED' ? input.reason : null,
      },
    });
    await tx.jobStatusHistory.create({
      data: {
        jobId: id,
        status: input.status,
        note: `ADMIN: ${input.reason}`,
        changedById: req.identity!.userId,
      },
    });
    const recipients = new Set([
      job.booking.customer.userId,
      ...job.assignments.map((assignment) => assignment.technician.userId),
    ]);
    await tx.notification.createMany({
      data: [...recipients].map((userId) => ({
        userId,
        title: input.status === 'CANCELLED' ? 'Job cancelled' : 'Job awaiting reassignment',
        body: input.reason,
        type: `JOB_${input.status}`,
      })),
    });
    await tx.auditLog.create({
      data: {
        businessId: tenant(req),
        actorId: req.identity!.userId,
        action: `JOB_${input.status}`,
        entity: 'Job',
        entityId: id,
        metadata: { previousStatus: job.status, reason: input.reason },
      },
    });
    return updated;
  });
  res.json({ data });
});

adminRouter.patch('/bookings/:id/reschedule', async (req: AuthRequest, res) => {
  const id = identifier.parse(req.params.id);
  const input = z.object({
    scheduledAt: z.coerce.date(),
    reason: z.string().trim().min(5).max(1000),
  }).parse(req.body);
  if (input.scheduledAt.getTime() < Date.now()) {
    throw new AppError(422, 'The revised schedule must be in the future', 'INVALID_SCHEDULE');
  }
  const booking = await db.booking.findFirst({
    where: {
      id,
      businessId: tenant(req),
      deletedAt: null,
      job: { status: { in: ['PENDING', 'ASSIGNED'] } },
    },
    include: {
      customer: true,
      service: true,
      job: {
        include: {
          assignments: {
            where: { unassignedAt: null },
            include: { technician: true },
          },
        },
      },
    },
  });
  if (!booking?.job) {
    throw new AppError(409, 'Only a pending or assigned job can be rescheduled', 'BOOKING_NOT_RESCHEDULABLE');
  }
  const targetStart = input.scheduledAt.getTime();
  const targetEnd = targetStart + booking.service.durationMinutes * 60_000;
  for (const assignment of booking.job.assignments) {
    const others = await db.jobAssignment.findMany({
      where: {
        technicianId: assignment.technicianId,
        jobId: { not: booking.job.id },
        unassignedAt: null,
        job: {
          status: { in: ['ASSIGNED', 'ACCEPTED', 'EN_ROUTE', 'IN_PROGRESS', 'PAUSED'] },
          booking: { businessId: tenant(req) },
        },
      },
      include: { job: { include: { booking: { include: { service: true } } } } },
    });
    const conflict = others.some((other) => {
      const start = other.job.booking.scheduledAt.getTime();
      const end = start + other.job.booking.service.durationMinutes * 60_000;
      return targetStart < end && start < targetEnd;
    });
    if (conflict) {
      throw new AppError(409, 'Assigned technician has a scheduling conflict', 'TECHNICIAN_SCHEDULE_CONFLICT');
    }
  }
  const data = await db.$transaction(async (tx) => {
    const updated = await tx.booking.update({
      where: { id },
      data: { scheduledAt: input.scheduledAt },
    });
    const recipients = new Set([
      booking.customer.userId,
      ...booking.job!.assignments.map((assignment) => assignment.technician.userId),
    ]);
    await tx.notification.createMany({
      data: [...recipients].map((userId) => ({
        userId,
        title: 'Booking rescheduled',
        body: `${input.reason} New schedule: ${input.scheduledAt.toISOString()}`,
        type: 'BOOKING_RESCHEDULED',
      })),
    });
    await tx.auditLog.create({
      data: {
        businessId: tenant(req),
        actorId: req.identity!.userId,
        action: 'BOOKING_RESCHEDULED',
        entity: 'Booking',
        entityId: id,
        metadata: {
          previousScheduledAt: booking.scheduledAt,
          scheduledAt: input.scheduledAt,
          reason: input.reason,
        },
      },
    });
    return updated;
  });
  res.json({ data });
});

const complaintQuery = page.extend({
  q: z.string().trim().max(160).optional(),
  status: z.enum(['OPEN', 'IN_PROGRESS', 'RESOLVED', 'REOPENED']).optional(),
  priority: z.enum(['LOW', 'NORMAL', 'HIGH', 'URGENT']).optional(),
});
const complaintInclude = {
  customer: { include: { user: { select: { id: true, name: true, email: true, phone: true } } } },
  booking: { include: { service: true } },
  technician: { include: { user: { select: { id: true, name: true, email: true, phone: true } } } },
} as const;

adminRouter.get('/complaints', async (req: AuthRequest, res) => {
  const input = complaintQuery.parse(req.query);
  const where = {
    businessId: tenant(req),
    ...(input.status ? { status: input.status } : {}),
    ...(input.priority ? { priority: input.priority } : {}),
    ...(input.q
      ? {
          OR: [
            { subject: { contains: input.q, mode: 'insensitive' as const } },
            { description: { contains: input.q, mode: 'insensitive' as const } },
            { customer: { user: { name: { contains: input.q, mode: 'insensitive' as const } } } },
          ],
        }
      : {}),
  };
  const [data, total] = await db.$transaction([
    db.supportTicket.findMany({
      where,
      skip: (input.page - 1) * input.limit,
      take: input.limit,
      orderBy: [{ priority: 'desc' }, { createdAt: 'desc' }],
      include: complaintInclude,
    }),
    db.supportTicket.count({ where }),
  ]);
  res.json({ data, meta: { page: input.page, limit: input.limit, total } });
});

adminRouter.get('/complaints/:id', async (req: AuthRequest, res) => {
  const id = identifier.parse(req.params.id);
  const data = await db.supportTicket.findFirst({
    where: { id, businessId: tenant(req) },
    include: complaintInclude,
  });
  if (!data) throw new AppError(404, 'Complaint not found');
  res.json({ data });
});

adminRouter.patch('/complaints/:id', async (req: AuthRequest, res) => {
  const id = identifier.parse(req.params.id);
  const input = z.object({
    priority: z.enum(['LOW', 'NORMAL', 'HIGH', 'URGENT']).optional(),
    assignedToId: z.string().uuid().nullable().optional(),
    adminNotes: nullableText,
  }).refine((value) => Object.keys(value).length > 0, 'At least one field is required').parse(req.body);
  const ticket = await db.supportTicket.findFirst({
    where: { id, businessId: tenant(req) },
  });
  if (!ticket) throw new AppError(404, 'Complaint not found');
  if (input.assignedToId) {
    const member = await db.businessMember.findFirst({
      where: {
        businessId: tenant(req),
        userId: input.assignedToId,
        active: true,
        user: { status: 'ACTIVE', deletedAt: null },
      },
    });
    if (!member) throw new AppError(422, 'Assignee is not an active business member', 'INVALID_ASSIGNEE');
  }
  const data = await db.supportTicket.update({ where: { id }, data: input });
  await audit(req, 'COMPLAINT_UPDATED', 'SupportTicket', id, {
    changedFields: Object.keys(input),
  });
  res.json({ data });
});

async function complaintTransition(
  req: AuthRequest,
  nextStatus: 'IN_PROGRESS' | 'RESOLVED' | 'REOPENED',
  details: { resolution?: string; reason?: string },
) {
  const id = identifier.parse(req.params.id);
  const ticket = await db.supportTicket.findFirst({
    where: { id, businessId: tenant(req) },
    include: { customer: true, technician: true },
  });
  if (!ticket) throw new AppError(404, 'Complaint not found');
  const allowed =
    nextStatus === 'IN_PROGRESS'
      ? ['OPEN', 'REOPENED']
      : nextStatus === 'RESOLVED'
        ? ['IN_PROGRESS']
        : ['RESOLVED'];
  if (!allowed.includes(ticket.status)) {
    throw new AppError(409, `Complaint cannot move from ${ticket.status} to ${nextStatus}`, 'INVALID_COMPLAINT_TRANSITION');
  }
  return db.$transaction(async (tx) => {
    const data = await tx.supportTicket.update({
      where: { id },
      data: {
        status: nextStatus,
        ...(nextStatus === 'RESOLVED'
          ? { resolution: details.resolution, resolvedAt: new Date() }
          : {}),
        ...(nextStatus === 'REOPENED'
          ? { reopenedAt: new Date(), resolvedAt: null }
          : {}),
      },
    });
    await tx.notification.create({
      data: {
        userId: ticket.customer.userId,
        title: 'Complaint status updated',
        body: `Your complaint is now ${nextStatus.toLowerCase().replaceAll('_', ' ')}.`,
        type: 'SUPPORT_TICKET',
      },
    });
    await tx.auditLog.create({
      data: {
        businessId: tenant(req),
        actorId: req.identity!.userId,
        action: `COMPLAINT_${nextStatus}`,
        entity: 'SupportTicket',
        entityId: id,
        metadata: { previousStatus: ticket.status, ...details },
      },
    });
    return data;
  });
}

adminRouter.post('/complaints/:id/start', async (req: AuthRequest, res) => {
  const data = await complaintTransition(req, 'IN_PROGRESS', {});
  res.json({ data });
});

adminRouter.post('/complaints/:id/resolve', async (req: AuthRequest, res) => {
  const input = z.object({ resolution: z.string().trim().min(10).max(5000) }).parse(req.body);
  const data = await complaintTransition(req, 'RESOLVED', input);
  res.json({ data });
});

adminRouter.post('/complaints/:id/reopen', async (req: AuthRequest, res) => {
  const input = z.object({ reason: z.string().trim().min(5).max(2000) }).parse(req.body);
  const data = await complaintTransition(req, 'REOPENED', input);
  res.json({ data });
});
