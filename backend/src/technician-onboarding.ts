import crypto from 'node:crypto';
import { Router } from 'express';
import { z } from 'zod';
import { db } from './db.js';
import { config } from './config.js';
import { AppError } from './errors.js';
import { allow } from './middleware.js';
import type { AuthRequest } from './types.js';

export const technicianOnboardingRouter = Router();
const technicianOnly = allow('TECHNICIAN');
const adminOnly = allow('ADMIN', 'MANAGER', 'SUPER_ADMIN');
const documentType = z.string().trim().regex(/^[A-Z][A-Z0-9_]{1,79}$/);
const allowedMimeTypes = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'application/pdf',
]);
const liveSelfieMimeTypes = new Set(['image/jpeg', 'image/png', 'image/webp']);

const addressInput = z.object({
  line1: z.string().trim().min(3).max(180),
  line2: z.string().trim().max(180).optional(),
  city: z.string().trim().min(2).max(100),
  state: z.string().trim().min(2).max(100),
  postalCode: z.string().trim().min(4).max(12),
});

const applicationInput = z.object({
  name: z.string().trim().min(2).max(120),
  phone: z.string().trim().regex(/^\+?[0-9]{10,15}$/),
  skills: z.array(z.string().trim().min(1).max(80)).min(1).max(50),
  experienceYears: z.coerce.number().int().min(0).max(80),
  address: addressInput,
  aadhaarNumber: z.string().transform((value) => value.replace(/[ -]/g, '')).pipe(z.string().regex(/^[0-9]{12}$/)),
  aadhaarConsent: z.literal(true),
});

function requiredDocumentTypes() {
  return [...new Set([
    ...(process.env.TECHNICIAN_REQUIRED_DOCUMENT_TYPES ?? 'IDENTITY,ADDRESS')
      .split(',')
      .map((value) => value.trim())
      .filter(Boolean),
    'LIVE_SELFIE',
  ])];
}

function aadhaarHash(aadhaarNumber: string) {
  return crypto
    .createHmac('sha256', config.AADHAAR_HASH_SECRET ?? config.JWT_ACCESS_SECRET)
    .update(`fieldops:aadhaar:v1:${aadhaarNumber}`)
    .digest('hex');
}

function safeApplication(data: any) {
  return {
    id: data.id,
    user: data.user,
    skills: data.skills,
    experienceYears: data.experienceYears,
    rating: data.rating,
    available: data.available,
    verificationStatus: data.verificationStatus,
    address: data.addressLine1
      ? {
          line1: data.addressLine1,
          line2: data.addressLine2,
          city: data.city,
          state: data.state,
          postalCode: data.postalCode,
        }
      : null,
    aadhaarMasked: data.aadhaarLast4 ? `XXXXXXXX${data.aadhaarLast4}` : null,
    aadhaarConsentAt: data.aadhaarConsentAt,
    profileCompletedAt: data.profileCompletedAt,
    documents: data.documents,
    serviceAreas: data.serviceAreas,
    requiredDocumentTypes: requiredDocumentTypes(),
  };
}

const applicationInclude = {
  user: { select: { id: true, name: true, email: true, phone: true, status: true } },
  documents: {
    select: {
      id: true,
      type: true,
      mimeType: true,
      status: true,
      rejectionReason: true,
      uploadedAt: true,
      reviewedAt: true,
    },
  },
  serviceAreas: { where: { active: true }, include: { serviceArea: true } },
} as const;

function tenant(req: AuthRequest) {
  return req.identity!.businessId;
}

function storageConfig() {
  const baseUrl = process.env.OBJECT_STORAGE_SIGNER_URL;
  const token = process.env.OBJECT_STORAGE_SIGNER_TOKEN;
  if (!baseUrl || !token) {
    throw new AppError(503, 'Protected document storage is not configured', 'STORAGE_NOT_CONFIGURED');
  }
  return { baseUrl: baseUrl.replace(/\/$/, ''), token };
}

async function storageCall(
  action: 'upload' | 'verify' | 'download',
  payload: Record<string, unknown>,
) {
  const config = storageConfig();
  let response: Response;
  try {
    response = await fetch(`${config.baseUrl}/${action}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${config.token}`,
      },
      body: JSON.stringify(payload),
    });
  } catch {
    throw new AppError(502, 'Protected document storage is unavailable', 'STORAGE_UNAVAILABLE');
  }
  if (!response.ok) {
    throw new AppError(502, 'Protected document storage rejected the request', 'STORAGE_PROVIDER_ERROR');
  }
  return await response.json() as Record<string, unknown>;
}

async function technicianProfile(req: AuthRequest) {
  const technician = await db.technician.findFirst({
    where: { userId: req.identity!.userId, businessId: tenant(req) },
    omit: { aadhaarHash: false },
  });
  if (!technician) throw new AppError(403, 'Technician profile required');
  return technician;
}

function normalizedSkills(skills: string[]) {
  return new Set(skills.map((skill) => skill.trim().toLowerCase()));
}

function hasRequiredSkills(technicianSkills: Set<string>, requiredSkills: string[]) {
  return requiredSkills.every((skill) => technicianSkills.has(skill.trim().toLowerCase()));
}

function distanceInKm(
  fromLat: number,
  fromLng: number,
  toLat: number,
  toLng: number,
) {
  const radians = (degrees: number) => (degrees * Math.PI) / 180;
  const latitudeDelta = radians(toLat - fromLat);
  const longitudeDelta = radians(toLng - fromLng);
  const a =
    Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(radians(fromLat)) *
      Math.cos(radians(toLat)) *
      Math.sin(longitudeDelta / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function redactedOpportunity(job: any, technician: any) {
  const address = job.booking.address;
  const canCalculateDistance =
    technician.locationLat !== null &&
    technician.locationLng !== null &&
    address.latitude !== null &&
    address.longitude !== null;
  const distanceKm = canCalculateDistance
    ? distanceInKm(
        Number(technician.locationLat),
        Number(technician.locationLng),
        Number(address.latitude),
        Number(address.longitude),
      )
    : null;
  return {
    id: job.id,
    service: {
      id: job.booking.service.id,
      name: job.booking.service.name,
      category: job.booking.service.category.name,
    },
    scheduledAt: job.booking.scheduledAt,
    estimatedPrice: job.booking.estimatedPrice,
    priority: job.priority,
    area: {
      city: address.city,
      state: address.state,
      postalCode: address.postalCode,
    },
    distanceKm: distanceKm === null ? null : Math.round(distanceKm * 10) / 10,
  };
}

const opportunityInclude = {
  booking: {
    include: {
      service: {
        include: {
          category: true,
          coverage: { where: { active: true }, select: { serviceAreaId: true } },
        },
      },
      address: true,
      customer: { select: { userId: true } },
    },
  },
} as const;

function ensureOpportunityEligible(technician: any) {
  if (
    technician.verificationStatus !== 'APPROVED' ||
    technician.available !== true ||
    technician.profileCompletedAt === null
  ) {
    throw new AppError(
      403,
      'An approved, complete and online technician profile is required',
      'TECHNICIAN_NOT_ELIGIBLE',
    );
  }
  const required = requiredDocumentTypes();
  if (
    !required.every((type) =>
      technician.documents.some(
        (document: { type: string; status: string }) =>
          document.type === type && document.status === 'APPROVED',
      ),
    )
  ) {
    throw new AppError(
      403,
      'All required eKYC documents must be approved',
      'TECHNICIAN_EKYC_INCOMPLETE',
    );
  }
  if (technician.serviceAreas.length === 0) {
    throw new AppError(
      403,
      'At least one active service area is required',
      'TECHNICIAN_AREA_NOT_CONFIGURED',
    );
  }
}

technicianOnboardingRouter.get(
  '/technician/application',
  technicianOnly,
  async (req: AuthRequest, res) => {
    const data = await db.technician.findFirst({
      where: { userId: req.identity!.userId, businessId: tenant(req) },
      include: applicationInclude,
    });
    if (!data) throw new AppError(404, 'Technician application not found');
    res.json({ data: safeApplication(data) });
  },
);

technicianOnboardingRouter.patch(
  '/technician/application',
  technicianOnly,
  async (req: AuthRequest, res) => {
    const input = applicationInput.parse(req.body);
    const technician = await technicianProfile(req);
    if (['SUSPENDED', 'INACTIVE'].includes(technician.verificationStatus)) {
      throw new AppError(409, 'The application cannot be edited in its current state', 'APPLICATION_EDIT_LOCKED');
    }
    const hash = aadhaarHash(input.aadhaarNumber);
    const aadhaarChanged = technician.aadhaarHash !== null && technician.aadhaarHash !== hash;
    const data = await db.$transaction(async (tx) => {
      await tx.user.update({
        where: { id: req.identity!.userId },
        data: { name: input.name, phone: input.phone },
      });
      const updated = await tx.technician.update({
        where: { id: technician.id },
        data: {
          skills: [...new Set(input.skills)],
          experienceYears: input.experienceYears,
          addressLine1: input.address.line1,
          addressLine2: input.address.line2 || null,
          city: input.address.city,
          state: input.address.state,
          postalCode: input.address.postalCode,
          aadhaarLast4: input.aadhaarNumber.slice(-4),
          aadhaarHash: hash,
          aadhaarConsentAt: new Date(),
          profileCompletedAt: new Date(),
          ...(aadhaarChanged
            ? { verificationStatus: 'DRAFT' as const, available: false }
            : {}),
        },
        include: applicationInclude,
      });
      const matchingAreas = await tx.serviceArea.findMany({
        where: {
          businessId: tenant(req),
          active: true,
          postalCodes: { has: input.address.postalCode },
        },
        select: { id: true },
      });
      if (matchingAreas.length > 0) {
        const serviceAreaIds = matchingAreas.map((area) => area.id);
        await tx.technicianServiceArea.updateMany({
          where: { technicianId: technician.id, serviceAreaId: { in: serviceAreaIds } },
          data: { active: true },
        });
        await tx.technicianServiceArea.createMany({
          data: serviceAreaIds.map((serviceAreaId) => ({
            technicianId: technician.id,
            serviceAreaId,
          })),
          skipDuplicates: true,
        });
      }
      await tx.auditLog.create({
        data: {
          businessId: tenant(req),
          actorId: req.identity!.userId,
          action: aadhaarChanged ? 'TECHNICIAN_IDENTITY_PROFILE_CHANGED' : 'TECHNICIAN_PROFILE_UPDATED',
          entity: 'Technician',
          entityId: technician.id,
          metadata: {
            fields: ['name', 'phone', 'skills', 'experienceYears', 'address', 'aadhaarVerificationReference'],
            verificationReset: aadhaarChanged,
          },
        },
      });
      return updated;
    });
    res.json({ data: safeApplication(data) });
  },
);

technicianOnboardingRouter.get(
  '/technician/progress',
  technicianOnly,
  async (req: AuthRequest, res) => {
    const technician = await db.technician.findFirst({
      where: { userId: req.identity!.userId, businessId: tenant(req) },
      include: {
        documents: { select: { type: true, status: true } },
        assignments: {
          where: { unassignedAt: null },
          select: { job: { select: { status: true } } },
        },
        ledgerEntries: {
          select: {
            grossAmount: true,
            netAmount: true,
            status: true,
          },
        },
        workReports: {
          select: {
            id: true,
            submittedAt: true,
            job: { select: { status: true } },
          },
        },
      },
    });
    if (!technician) throw new AppError(404, 'Technician application not found');
    const required = requiredDocumentTypes();
    const activeStatuses = new Set(['ASSIGNED', 'ACCEPTED', 'EN_ROUTE', 'IN_PROGRESS', 'PAUSED']);
    const jobs = technician.assignments.map((item) => item.job);
    const completedJobs = jobs.filter((job) => job.status === 'COMPLETED').length;
    const earnings = technician.ledgerEntries.reduce(
      (total, entry) => ({
        gross: total.gross + Number(entry.grossAmount),
        net: total.net + Number(entry.netAmount),
        available: total.available + (entry.status === 'AVAILABLE' ? Number(entry.netAmount) : 0),
        paid: total.paid + (entry.status === 'PAID' ? Number(entry.netAmount) : 0),
      }),
      { gross: 0, net: 0, available: 0, paid: 0 },
    );
    const submitted = required.filter((type) =>
      technician.documents.some((document) => document.type === type && document.status !== 'REJECTED'),
    ).length;
    const approved = required.filter((type) =>
      technician.documents.some((document) => document.type === type && document.status === 'APPROVED'),
    ).length;
    res.json({
      data: {
        verificationStatus: technician.verificationStatus,
        profileComplete: technician.profileCompletedAt !== null,
        available: technician.available,
        rating: technician.rating,
        documents: { required: required.length, submitted, approved },
        jobs: {
          total: jobs.length,
          active: jobs.filter((job) => activeStatuses.has(job.status)).length,
          completed: completedJobs,
          completionRate: jobs.length === 0 ? 0 : Math.round((completedJobs / jobs.length) * 100),
          reportsSubmitted: technician.workReports.filter((report) => report.submittedAt !== null).length,
          pendingApprovals: technician.workReports.filter(
            (report) => report.submittedAt !== null && report.job.status !== 'COMPLETED',
          ).length,
        },
        earnings,
      },
    });
  },
);

technicianOnboardingRouter.get(
  '/technician/opportunities',
  technicianOnly,
  async (req: AuthRequest, res) => {
    const technician = await db.technician.findFirst({
      where: { userId: req.identity!.userId, businessId: tenant(req) },
      include: {
        documents: { select: { type: true, status: true } },
        serviceAreas: {
          where: { active: true, serviceArea: { active: true } },
          include: { serviceArea: true },
        },
      },
    });
    if (!technician) throw new AppError(403, 'Technician profile required');
    ensureOpportunityEligible(technician);
    const serviceAreaIds = technician.serviceAreas.map((item) => item.serviceAreaId);
    const postalCodes = [...new Set(technician.serviceAreas.flatMap((item) => item.serviceArea.postalCodes))];
    const jobs = await db.job.findMany({
      where: {
        status: 'PENDING',
        assignments: { none: { unassignedAt: null } },
        booking: {
          businessId: tenant(req),
          deletedAt: null,
          scheduledAt: { gte: new Date() },
          status: { in: ['PENDING', 'CONFIRMED'] },
          address: { postalCode: { in: postalCodes } },
          service: {
            active: true,
            deletedAt: null,
            coverage: {
              some: { active: true, serviceAreaId: { in: serviceAreaIds } },
            },
          },
        },
      },
      include: opportunityInclude,
      orderBy: { booking: { scheduledAt: 'asc' } },
      take: 100,
    });
    const skills = normalizedSkills(technician.skills);
    const data = jobs
      .filter((job) => hasRequiredSkills(skills, job.booking.service.requiredSkills))
      .map((job) => redactedOpportunity(job, technician))
      .sort((left, right) => {
        if (left.distanceKm === null) return right.distanceKm === null ? 0 : 1;
        if (right.distanceKm === null) return -1;
        return left.distanceKm - right.distanceKm;
      });
    res.json({ data });
  },
);

technicianOnboardingRouter.post(
  '/technician/opportunities/:id/claim',
  technicianOnly,
  async (req: AuthRequest, res) => {
    const jobId = z.string().uuid().parse(req.params.id);
    try {
      const data = await db.$transaction(
        async (tx) => {
          const technician = await tx.technician.findFirst({
            where: { userId: req.identity!.userId, businessId: tenant(req) },
            include: {
              documents: { select: { type: true, status: true } },
              serviceAreas: {
                where: { active: true, serviceArea: { active: true } },
                include: { serviceArea: true },
              },
            },
          });
          if (!technician) throw new AppError(403, 'Technician profile required');
          ensureOpportunityEligible(technician);
          await tx.$queryRaw`SELECT "id" FROM "Job" WHERE "id" = ${jobId} FOR UPDATE`;
          const job = await tx.job.findFirst({
            where: {
              id: jobId,
              status: 'PENDING',
              assignments: { none: { unassignedAt: null } },
              booking: {
                businessId: tenant(req),
                deletedAt: null,
                status: { in: ['PENDING', 'CONFIRMED'] },
              },
            },
            include: opportunityInclude,
          });
          if (!job) {
            throw new AppError(409, 'This opportunity is no longer available', 'OPPORTUNITY_NOT_AVAILABLE');
          }
          const activeAreaIds = new Set(technician.serviceAreas.map((item) => item.serviceAreaId));
          const areaEligible =
            technician.serviceAreas.some((item) =>
              item.serviceArea.postalCodes.includes(job.booking.address.postalCode),
            ) &&
            job.booking.service.coverage.some((coverage) =>
              activeAreaIds.has(coverage.serviceAreaId),
            );
          if (!areaEligible) {
            throw new AppError(403, 'This job is outside your service area', 'TECHNICIAN_AREA_MISMATCH');
          }
          if (!hasRequiredSkills(normalizedSkills(technician.skills), job.booking.service.requiredSkills)) {
            throw new AppError(403, 'Your verified skills do not match this job', 'TECHNICIAN_SKILL_MISMATCH');
          }
          const activeAssignments = await tx.jobAssignment.findMany({
            where: {
              technicianId: technician.id,
              unassignedAt: null,
              job: {
                status: { in: ['ASSIGNED', 'ACCEPTED', 'EN_ROUTE', 'IN_PROGRESS', 'PAUSED'] },
                booking: { businessId: tenant(req) },
              },
            },
            include: { job: { include: { booking: { include: { service: true } } } } },
          });
          const targetStart = job.booking.scheduledAt.getTime();
          const targetEnd = targetStart + job.booking.service.durationMinutes * 60_000;
          const scheduleConflict = activeAssignments.some((item) => {
            const otherStart = item.job.booking.scheduledAt.getTime();
            const otherEnd = otherStart + item.job.booking.service.durationMinutes * 60_000;
            return targetStart < otherEnd && otherStart < targetEnd;
          });
          if (scheduleConflict) {
            throw new AppError(409, 'You already have an overlapping active job', 'TECHNICIAN_SCHEDULE_CONFLICT');
          }
          const assignment = await tx.jobAssignment.create({
            data: { jobId: job.id, technicianId: technician.id },
          });
          const updatedJob = await tx.job.update({
            where: { id: job.id },
            data: { status: 'ASSIGNED' },
          });
          await tx.booking.update({
            where: { id: job.bookingId },
            data: { status: 'ASSIGNED' },
          });
          await tx.jobStatusHistory.create({
            data: {
              jobId: job.id,
              status: 'ASSIGNED',
              note: 'TECHNICIAN_SELF_CLAIMED',
              changedById: req.identity!.userId,
            },
          });
          await tx.notification.createMany({
            data: [
              {
                userId: technician.userId,
                title: 'Job registered',
                body: `${job.booking.service.name} has been added to your jobs.`,
                type: 'JOB_CLAIMED',
              },
              {
                userId: job.booking.customer.userId,
                title: 'Technician assigned',
                body: 'A verified technician has accepted your service request.',
                type: 'JOB_ASSIGNED',
              },
            ],
          });
          await tx.auditLog.create({
            data: {
              businessId: tenant(req),
              actorId: req.identity!.userId,
              action: 'TECHNICIAN_CLAIMED_OPPORTUNITY',
              entity: 'Job',
              entityId: job.id,
              metadata: { technicianId: technician.id },
            },
          });
          return { assignment, job: updatedJob };
        },
        { isolationLevel: 'Serializable' },
      );
      res.status(201).json({ data });
    } catch (error) {
      const code =
        typeof error === 'object' && error !== null && 'code' in error
          ? String((error as { code: unknown }).code)
          : null;
      if (code === 'P2002' || code === 'P2034') {
        throw new AppError(409, 'This opportunity was claimed by another technician', 'OPPORTUNITY_ALREADY_CLAIMED');
      }
      throw error;
    }
  },
);

technicianOnboardingRouter.post(
  '/technician/documents/upload-intent',
  technicianOnly,
  async (req: AuthRequest, res) => {
    const input = z.object({
      type: documentType,
      mimeType: z.string().trim().max(100),
      size: z.coerce.number().int().positive().max(10 * 1024 * 1024),
      fileName: z.string().trim().min(1).max(180),
    }).parse(req.body);
    if (!allowedMimeTypes.has(input.mimeType)) {
      throw new AppError(422, 'Only JPEG, PNG, WebP or PDF documents are accepted', 'DOCUMENT_TYPE_NOT_ALLOWED');
    }
    if (input.type === 'LIVE_SELFIE' && !liveSelfieMimeTypes.has(input.mimeType)) {
      throw new AppError(422, 'The live selfie must be a JPEG, PNG or WebP image', 'LIVE_SELFIE_IMAGE_REQUIRED');
    }
    const technician = await technicianProfile(req);
    if (['APPROVED', 'SUSPENDED', 'INACTIVE'].includes(technician.verificationStatus)) {
      throw new AppError(409, 'Documents cannot be replaced in the current verification state', 'DOCUMENT_UPLOAD_LOCKED');
    }
    const extension = input.fileName.split('.').pop()?.toLowerCase().replace(/[^a-z0-9]/g, '') || 'bin';
    const objectKey = `${tenant(req)}/technicians/${technician.id}/documents/${input.type}/${crypto.randomUUID()}.${extension}`;
    const provider = await storageCall('upload', {
      objectKey,
      mimeType: input.mimeType,
      size: input.size,
      expiresInSeconds: 900,
    });
    const parsed = z.object({
      url: z.string().url(),
      headers: z.record(z.string(), z.string()).optional(),
      expiresAt: z.string().optional(),
    }).parse(provider);
    res.status(201).json({
      data: {
        uploadUrl: parsed.url,
        headers: parsed.headers ?? {},
        objectKey,
        expiresAt: parsed.expiresAt,
      },
    });
  },
);

technicianOnboardingRouter.post(
  '/technician/documents',
  technicianOnly,
  async (req: AuthRequest, res) => {
    const input = z.object({
      type: documentType,
      objectKey: z.string().trim().min(10).max(700),
      mimeType: z.string().trim().max(100),
    }).parse(req.body);
    if (!allowedMimeTypes.has(input.mimeType)) {
      throw new AppError(422, 'Document format is not supported', 'DOCUMENT_TYPE_NOT_ALLOWED');
    }
    if (input.type === 'LIVE_SELFIE' && !liveSelfieMimeTypes.has(input.mimeType)) {
      throw new AppError(422, 'The live selfie must be an image', 'LIVE_SELFIE_IMAGE_REQUIRED');
    }
    const technician = await technicianProfile(req);
    if (!input.objectKey.startsWith(`${tenant(req)}/technicians/${technician.id}/documents/`)) {
      throw new AppError(422, 'Document object does not belong to this application', 'INVALID_DOCUMENT_OBJECT');
    }
    if (['APPROVED', 'SUSPENDED', 'INACTIVE'].includes(technician.verificationStatus)) {
      throw new AppError(409, 'Documents cannot be changed in the current verification state', 'DOCUMENT_UPLOAD_LOCKED');
    }
    const verified = await storageCall('verify', {
      objectKey: input.objectKey,
      mimeType: input.mimeType,
      maxSize: 10 * 1024 * 1024,
      malwareScanRequired: true,
    });
    if (verified.exists !== true || verified.safe !== true) {
      throw new AppError(422, 'Uploaded document is missing or has not passed security scanning', 'DOCUMENT_NOT_VERIFIED');
    }
    const data = await db.$transaction(async (tx) => {
      const document = await tx.technicianDocument.upsert({
        where: { technicianId_type: { technicianId: technician.id, type: input.type } },
        create: {
          technicianId: technician.id,
          type: input.type,
          objectKey: input.objectKey,
          mimeType: input.mimeType,
        },
        update: {
          objectKey: input.objectKey,
          mimeType: input.mimeType,
          status: 'PENDING',
          rejectionReason: null,
          uploadedAt: new Date(),
          reviewedAt: null,
          reviewedById: null,
        },
      });
      await tx.technician.update({
        where: { id: technician.id },
        data: { verificationStatus: 'DRAFT', available: false },
      });
      await tx.auditLog.create({
        data: {
          businessId: tenant(req),
          actorId: req.identity!.userId,
          action: 'TECHNICIAN_DOCUMENT_REGISTERED',
          entity: 'TechnicianDocument',
          entityId: document.id,
          metadata: { type: input.type },
        },
      });
      return document;
    });
    res.status(201).json({
      data: {
        id: data.id,
        type: data.type,
        status: data.status,
        uploadedAt: data.uploadedAt,
      },
    });
  },
);

technicianOnboardingRouter.post(
  '/technician/verification/submit',
  technicianOnly,
  async (req: AuthRequest, res) => {
    const technician = await db.technician.findFirst({
      where: { userId: req.identity!.userId, businessId: tenant(req) },
      include: { documents: true },
      omit: { aadhaarHash: false },
    });
    if (!technician) throw new AppError(403, 'Technician profile required');
    if (
      !technician.profileCompletedAt ||
      !technician.aadhaarHash ||
      !technician.aadhaarConsentAt ||
      !technician.addressLine1 ||
      !technician.city ||
      !technician.state ||
      !technician.postalCode
    ) {
      throw new AppError(
        422,
        'Complete your profile and Aadhaar consent before submitting eKYC',
        'TECHNICIAN_PROFILE_INCOMPLETE',
      );
    }
    if (!['DRAFT', 'REJECTED'].includes(technician.verificationStatus)) {
      throw new AppError(409, 'Application cannot be submitted in its current state', 'INVALID_VERIFICATION_TRANSITION');
    }
    const required = requiredDocumentTypes();
    const missing = required.filter(
      (type) => !technician.documents.some((document) => document.type === type && document.status !== 'REJECTED'),
    );
    if (missing.length > 0) {
      throw new AppError(422, `Missing required documents: ${missing.join(', ')}`, 'REQUIRED_DOCUMENTS_MISSING');
    }
    const data = await db.$transaction(async (tx) => {
      const updated = await tx.technician.update({
        where: { id: technician.id },
        data: { verificationStatus: 'PENDING_VERIFICATION', available: false },
      });
      const reviewers = await tx.businessMember.findMany({
        where: {
          businessId: tenant(req),
          active: true,
          role: { name: { in: ['ADMIN', 'MANAGER', 'SUPER_ADMIN'] } },
          user: { status: 'ACTIVE', deletedAt: null },
        },
        select: { userId: true },
      });
      if (reviewers.length > 0) {
        await tx.notification.createMany({
          data: reviewers.map((reviewer) => ({
            userId: reviewer.userId,
            title: 'Technician verification pending',
            body: 'A technician submitted all required documents for review.',
            type: 'TECHNICIAN_VERIFICATION',
          })),
        });
      }
      await tx.auditLog.create({
        data: {
          businessId: tenant(req),
          actorId: req.identity!.userId,
          action: 'TECHNICIAN_VERIFICATION_SUBMITTED',
          entity: 'Technician',
          entityId: technician.id,
          metadata: { requiredDocumentTypes: required },
        },
      });
      return updated;
    });
    res.json({ data });
  },
);

technicianOnboardingRouter.get(
  '/admin/technicians/:id/documents/:documentId/download',
  adminOnly,
  async (req: AuthRequest, res) => {
    const input = z.object({ id: z.string().uuid(), documentId: z.string().uuid() }).parse(req.params);
    const document = await db.technicianDocument.findFirst({
      where: {
        id: input.documentId,
        technicianId: input.id,
        technician: { businessId: tenant(req) },
      },
    });
    if (!document) throw new AppError(404, 'Technician document not found');
    const provider = await storageCall('download', {
      objectKey: document.objectKey,
      expiresInSeconds: 300,
      disposition: 'inline',
    });
    const parsed = z.object({ url: z.string().url(), expiresAt: z.string().optional() }).parse(provider);
    await db.auditLog.create({
      data: {
        businessId: tenant(req),
        actorId: req.identity!.userId,
        action: 'TECHNICIAN_DOCUMENT_VIEWED',
        entity: 'TechnicianDocument',
        entityId: document.id,
      },
    });
    res.json({ data: { url: parsed.url, expiresAt: parsed.expiresAt } });
  },
);
