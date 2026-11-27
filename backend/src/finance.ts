import { Router } from 'express';
import { z } from 'zod';
import { db } from './db.js';
import { AppError } from './errors.js';
import { allow } from './middleware.js';
import type { AuthRequest } from './types.js';

export const financeRouter = Router();

const admin = allow('ADMIN', 'MANAGER', 'SUPER_ADMIN');
const technician = allow('TECHNICIAN');
const page = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});
const identifier = z.string().uuid();

function tenant(req: AuthRequest) {
  return req.identity!.businessId;
}

function requestKey(req: AuthRequest, namespace: string) {
  const value = req.header('Idempotency-Key');
  if (!value || value.length < 8 || value.length > 200) {
    throw new AppError(422, 'A valid Idempotency-Key header is required', 'IDEMPOTENCY_KEY_REQUIRED');
  }
  return `${namespace}:${tenant(req)}:${value}`;
}

async function recordRefundFailure(req: AuthRequest, id: string, reason: string) {
  const failureReason = reason.slice(0, 1000);
  await db.$transaction([
    db.refund.update({
      where: { id },
      data: { status: 'FAILED', failureReason, processedAt: new Date() },
    }),
    db.auditLog.create({
      data: {
        businessId: tenant(req),
        actorId: req.identity!.userId,
        action: 'REFUND_FAILED',
        entity: 'Refund',
        entityId: id,
        metadata: { failureReason },
      },
    }),
  ]);
}

financeRouter.get('/admin/payments', admin, async (req: AuthRequest, res) => {
  const input = page.extend({
    q: z.string().trim().max(160).optional(),
    status: z.enum(['PENDING', 'AUTHORIZED', 'PAID', 'FAILED', 'REFUNDED']).optional(),
    method: z.enum(['ONLINE', 'CASH']).optional(),
  }).parse(req.query);
  const where = {
    invoice: { businessId: tenant(req) },
    ...(input.status ? { status: input.status } : {}),
    ...(input.method ? { method: input.method } : {}),
    ...(input.q
      ? {
          OR: [
            { providerPaymentId: { contains: input.q, mode: 'insensitive' as const } },
            { invoice: { number: { contains: input.q, mode: 'insensitive' as const } } },
            {
              invoice: {
                booking: {
                  customer: {
                    user: { name: { contains: input.q, mode: 'insensitive' as const } },
                  },
                },
              },
            },
          ],
        }
      : {}),
  };
  const [data, total] = await db.$transaction([
    db.payment.findMany({
      where,
      skip: (input.page - 1) * input.limit,
      take: input.limit,
      orderBy: { createdAt: 'desc' },
      include: {
        invoice: {
          include: {
            booking: {
              include: {
                customer: { include: { user: { select: { id: true, name: true, email: true } } } },
                service: true,
              },
            },
          },
        },
        refunds: true,
        cashCollection: {
          include: { technician: { include: { user: { select: { id: true, name: true } } } } },
        },
      },
    }),
    db.payment.count({ where }),
  ]);
  res.json({ data, meta: { page: input.page, limit: input.limit, total } });
});

financeRouter.get('/admin/refunds', admin, async (req: AuthRequest, res) => {
  const input = page.extend({
    status: z.enum(['REQUESTED', 'APPROVED', 'PROCESSING', 'SUCCEEDED', 'FAILED', 'REJECTED']).optional(),
  }).parse(req.query);
  const where = {
    payment: { invoice: { businessId: tenant(req) } },
    ...(input.status ? { status: input.status } : {}),
  };
  const [data, total] = await db.$transaction([
    db.refund.findMany({
      where,
      skip: (input.page - 1) * input.limit,
      take: input.limit,
      orderBy: { createdAt: 'desc' },
      include: {
        payment: {
          include: {
            invoice: {
              include: {
                booking: { include: { customer: { include: { user: true } }, service: true } },
              },
            },
          },
        },
      },
    }),
    db.refund.count({ where }),
  ]);
  res.json({ data, meta: { page: input.page, limit: input.limit, total } });
});

financeRouter.post('/admin/payments/:id/refunds', admin, async (req: AuthRequest, res) => {
  const paymentId = identifier.parse(req.params.id);
  const input = z.object({
    amount: z.coerce.number().positive().max(100000000),
    reason: z.string().trim().min(5).max(1000),
  }).parse(req.body);
  const idempotencyKey = requestKey(req, 'refund');
  const existing = await db.refund.findUnique({ where: { idempotencyKey } });
  if (existing) {
    if (existing.paymentId !== paymentId) {
      throw new AppError(409, 'Idempotency key was already used for another payment', 'IDEMPOTENCY_CONFLICT');
    }
    return void res.json({ data: existing, duplicate: true });
  }
  const payment = await db.payment.findFirst({
    where: {
      id: paymentId,
      status: { in: ['PAID', 'REFUNDED'] },
      invoice: { businessId: tenant(req) },
    },
  });
  if (!payment) throw new AppError(409, 'Only a verified payment can be refunded', 'PAYMENT_NOT_REFUNDABLE');
  const reserved = await db.refund.aggregate({
    _sum: { amount: true },
    where: {
      paymentId,
      status: { in: ['REQUESTED', 'APPROVED', 'PROCESSING', 'SUCCEEDED'] },
    },
  });
  const remaining = Number(payment.amount) - Number(reserved._sum.amount ?? 0);
  if (input.amount > remaining + 0.000001) {
    throw new AppError(422, `Refund amount exceeds the refundable balance of ${remaining}`, 'REFUND_AMOUNT_EXCEEDED');
  }
  const data = await db.$transaction(async (tx) => {
    const created = await tx.refund.create({
      data: {
        paymentId,
        amount: input.amount,
        reason: input.reason,
        idempotencyKey,
      },
    });
    await tx.auditLog.create({
      data: {
        businessId: tenant(req),
        actorId: req.identity!.userId,
        action: 'REFUND_REQUESTED',
        entity: 'Refund',
        entityId: created.id,
        metadata: { paymentId, amount: input.amount, reason: input.reason },
      },
    });
    return created;
  });
  res.status(201).json({ data });
});

financeRouter.post('/admin/refunds/:id/approve', admin, async (req: AuthRequest, res) => {
  const id = identifier.parse(req.params.id);
  const refund = await db.refund.findFirst({
    where: { id, status: 'REQUESTED', payment: { invoice: { businessId: tenant(req) } } },
  });
  if (!refund) throw new AppError(409, 'Refund is not awaiting approval', 'INVALID_REFUND_TRANSITION');
  const data = await db.$transaction(async (tx) => {
    const updated = await tx.refund.update({
      where: { id },
      data: { status: 'APPROVED', reviewedById: req.identity!.userId },
    });
    await tx.auditLog.create({
      data: {
        businessId: tenant(req),
        actorId: req.identity!.userId,
        action: 'REFUND_APPROVED',
        entity: 'Refund',
        entityId: id,
      },
    });
    return updated;
  });
  res.json({ data });
});

financeRouter.post('/admin/refunds/:id/reject', admin, async (req: AuthRequest, res) => {
  const id = identifier.parse(req.params.id);
  const input = z.object({ reason: z.string().trim().min(5).max(1000) }).parse(req.body);
  const refund = await db.refund.findFirst({
    where: {
      id,
      status: { in: ['REQUESTED', 'APPROVED'] },
      payment: { invoice: { businessId: tenant(req) } },
    },
  });
  if (!refund) throw new AppError(409, 'Refund cannot be rejected in its current state', 'INVALID_REFUND_TRANSITION');
  const data = await db.$transaction(async (tx) => {
    const updated = await tx.refund.update({
      where: { id },
      data: {
        status: 'REJECTED',
        failureReason: input.reason,
        reviewedById: req.identity!.userId,
        processedAt: new Date(),
      },
    });
    await tx.auditLog.create({
      data: {
        businessId: tenant(req),
        actorId: req.identity!.userId,
        action: 'REFUND_REJECTED',
        entity: 'Refund',
        entityId: id,
        metadata: { reason: input.reason },
      },
    });
    return updated;
  });
  res.json({ data });
});

financeRouter.post('/admin/refunds/:id/process', admin, async (req: AuthRequest, res) => {
  const id = identifier.parse(req.params.id);
  const refund = await db.refund.findFirst({
    where: {
      id,
      status: { in: ['APPROVED', 'FAILED'] },
      payment: { invoice: { businessId: tenant(req) } },
    },
    include: { payment: true },
  });
  if (!refund) throw new AppError(409, 'Refund is not ready for processing', 'INVALID_REFUND_TRANSITION');
  if (refund.payment.provider !== 'RAZORPAY' || !refund.payment.providerPaymentId) {
    throw new AppError(422, 'This payment has no supported provider refund route', 'REFUND_PROVIDER_UNAVAILABLE');
  }
  const key = process.env.RAZORPAY_KEY_ID;
  const secret = process.env.RAZORPAY_KEY_SECRET;
  if (!key || !secret) throw new AppError(503, 'Refund provider is not configured', 'NOT_CONFIGURED');

  await db.refund.update({
    where: { id },
    data: { status: 'PROCESSING', failureReason: null },
  });
  let response: Response;
  try {
    response = await fetch(
      `https://api.razorpay.com/v1/payments/${encodeURIComponent(refund.payment.providerPaymentId)}/refund`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Basic ${Buffer.from(`${key}:${secret}`).toString('base64')}`,
          'X-Razorpay-Idempotency-Key': refund.idempotencyKey,
        },
        body: JSON.stringify({
          amount: Math.round(Number(refund.amount) * 100),
          notes: { fieldopsRefundId: refund.id },
        }),
      },
    );
  } catch (error) {
    await recordRefundFailure(
      req,
      id,
      error instanceof Error ? error.message : 'Refund provider is unreachable',
    );
    throw new AppError(502, 'Refund provider is unreachable', 'REFUND_PROVIDER_ERROR');
  }
  const providerText = await response.text();
  let providerData: { id?: string; error?: { description?: string } } = {};
  try {
    providerData = JSON.parse(providerText);
  } catch {
    providerData = {};
  }
  if (!response.ok || !providerData.id) {
    const failureReason = (providerData.error?.description || providerText || 'Refund provider failed').slice(0, 1000);
    await recordRefundFailure(req, id, failureReason);
    throw new AppError(502, 'Refund provider rejected the request', 'REFUND_PROVIDER_ERROR');
  }
  const data = await db.$transaction(async (tx) => {
    const updated = await tx.refund.update({
      where: { id },
      data: {
        status: 'SUCCEEDED',
        providerRefundId: providerData.id,
        processedAt: new Date(),
        failureReason: null,
      },
    });
    const refunded = await tx.refund.aggregate({
      _sum: { amount: true },
      where: { paymentId: refund.paymentId, status: 'SUCCEEDED' },
    });
    if (Number(refunded._sum.amount ?? 0) + 0.000001 >= Number(refund.payment.amount)) {
      await tx.payment.update({ where: { id: refund.paymentId }, data: { status: 'REFUNDED' } });
    }
    await tx.auditLog.create({
      data: {
        businessId: tenant(req),
        actorId: req.identity!.userId,
        action: 'REFUND_SUCCEEDED',
        entity: 'Refund',
        entityId: id,
        metadata: { providerRefundId: providerData.id },
      },
    });
    return updated;
  });
  res.json({ data, serverVerified: true });
});

financeRouter.post('/technician/invoices/:id/cash-collection', technician, async (req: AuthRequest, res) => {
  const invoiceId = identifier.parse(req.params.id);
  const input = z.object({
    amount: z.coerce.number().positive().max(100000000),
    receiptObjectKey: z.string().trim().min(3).max(500),
    collectedAt: z.coerce.date(),
  }).parse(req.body);
  if (input.collectedAt.getTime() > Date.now() + 5 * 60 * 1000) {
    throw new AppError(422, 'Cash collection time cannot be in the future', 'INVALID_COLLECTION_TIME');
  }
  if (!input.receiptObjectKey.startsWith(`${tenant(req)}/`)) {
    throw new AppError(422, 'Receipt object does not belong to this business', 'INVALID_RECEIPT_OBJECT');
  }
  const idempotencyKey = requestKey(req, 'cash');
  const existing = await db.payment.findUnique({
    where: { idempotencyKey },
    include: { cashCollection: true },
  });
  if (existing) {
    if (existing.invoiceId !== invoiceId) {
      throw new AppError(409, 'Idempotency key was already used for another invoice', 'IDEMPOTENCY_CONFLICT');
    }
    return void res.json({ data: existing, duplicate: true });
  }
  const tech = await db.technician.findFirst({
    where: {
      userId: req.identity!.userId,
      businessId: tenant(req),
      verificationStatus: 'APPROVED',
    },
  });
  if (!tech) throw new AppError(403, 'Approved technician profile required', 'TECHNICIAN_NOT_APPROVED');
  const invoice = await db.invoice.findFirst({
    where: {
      id: invoiceId,
      businessId: tenant(req),
      booking: {
        job: {
          assignments: { some: { technicianId: tech.id, unassignedAt: null } },
          report: { is: { submittedAt: { not: null } } },
        },
      },
    },
    include: { booking: { include: { customer: true } } },
  });
  if (!invoice) {
    throw new AppError(403, 'Cash can be submitted only for an assigned job with a work report', 'CASH_COLLECTION_FORBIDDEN');
  }
  const paid = await db.payment.aggregate({
    _sum: { amount: true },
    where: { invoiceId, status: 'PAID' },
  });
  const outstanding = Number(invoice.total) - Number(paid._sum.amount ?? 0);
  if (input.amount > outstanding + 0.000001) {
    throw new AppError(422, `Cash amount exceeds the outstanding balance of ${outstanding}`, 'PAYMENT_AMOUNT_EXCEEDED');
  }
  const data = await db.$transaction(async (tx) => {
    const payment = await tx.payment.create({
      data: {
        invoiceId,
        provider: 'CASH',
        method: 'CASH',
        idempotencyKey,
        amount: input.amount,
        status: 'PENDING',
        cashCollection: {
          create: {
            technicianId: tech.id,
            receiptObjectKey: input.receiptObjectKey,
            amount: input.amount,
            collectedAt: input.collectedAt,
          },
        },
      },
      include: { cashCollection: true },
    });
    await tx.auditLog.create({
      data: {
        businessId: tenant(req),
        actorId: req.identity!.userId,
        action: 'CASH_COLLECTION_SUBMITTED',
        entity: 'Payment',
        entityId: payment.id,
        metadata: { invoiceId, amount: input.amount },
      },
    });
    return payment;
  });
  res.status(201).json({ data, status: 'ADMIN_VERIFICATION_PENDING' });
});

financeRouter.get('/admin/cash-collections', admin, async (req: AuthRequest, res) => {
  const input = page.extend({
    status: z.enum(['SUBMITTED', 'VERIFIED', 'REJECTED']).optional(),
  }).parse(req.query);
  const where = {
    payment: { invoice: { businessId: tenant(req) } },
    ...(input.status ? { status: input.status } : {}),
  };
  const [data, total] = await db.$transaction([
    db.cashCollection.findMany({
      where,
      skip: (input.page - 1) * input.limit,
      take: input.limit,
      orderBy: { submittedAt: 'desc' },
      include: {
        technician: { include: { user: { select: { id: true, name: true, email: true } } } },
        payment: {
          include: {
            invoice: {
              include: {
                booking: { include: { customer: { include: { user: true } }, service: true } },
              },
            },
          },
        },
      },
    }),
    db.cashCollection.count({ where }),
  ]);
  res.json({ data, meta: { page: input.page, limit: input.limit, total } });
});

financeRouter.post('/admin/cash-collections/:id/verify', admin, async (req: AuthRequest, res) => {
  const id = identifier.parse(req.params.id);
  const collection = await db.cashCollection.findFirst({
    where: {
      id,
      status: 'SUBMITTED',
      payment: { status: 'PENDING', invoice: { businessId: tenant(req) } },
    },
    include: {
      technician: true,
      payment: { include: { invoice: { include: { booking: { include: { customer: true } } } } } },
    },
  });
  if (!collection) throw new AppError(409, 'Cash collection is not awaiting verification', 'INVALID_CASH_TRANSITION');
  if (collection.technician.userId === req.identity!.userId) {
    throw new AppError(403, 'The collector cannot verify their own cash receipt', 'SELF_VERIFICATION_FORBIDDEN');
  }
  if (Math.abs(Number(collection.amount) - Number(collection.payment.amount)) > 0.000001) {
    throw new AppError(409, 'Receipt amount does not match the payment amount', 'CASH_AMOUNT_MISMATCH');
  }
  const data = await db.$transaction(async (tx) => {
    const updated = await tx.cashCollection.update({
      where: { id },
      data: { status: 'VERIFIED', verifiedAt: new Date(), verifiedById: req.identity!.userId },
    });
    await tx.payment.update({
      where: { id: collection.paymentId },
      data: { status: 'PAID', verifiedAt: new Date(), failureReason: null },
    });
    const paid = await tx.payment.aggregate({
      _sum: { amount: true },
      where: { invoiceId: collection.payment.invoiceId, status: 'PAID' },
    });
    if (Number(paid._sum.amount ?? 0) + 0.000001 >= Number(collection.payment.invoice.total)) {
      await tx.invoice.update({ where: { id: collection.payment.invoiceId }, data: { status: 'PAID' } });
    }
    await tx.notification.createMany({
      data: [
        {
          userId: collection.technician.userId,
          title: 'Cash receipt verified',
          body: 'The submitted cash collection has been verified.',
          type: 'CASH_VERIFIED',
        },
        {
          userId: collection.payment.invoice.booking.customer.userId,
          title: 'Cash payment verified',
          body: 'Your cash payment receipt has been verified.',
          type: 'PAYMENT_VERIFIED',
        },
      ],
    });
    await tx.auditLog.create({
      data: {
        businessId: tenant(req),
        actorId: req.identity!.userId,
        action: 'CASH_COLLECTION_VERIFIED',
        entity: 'CashCollection',
        entityId: id,
        metadata: { paymentId: collection.paymentId, amount: Number(collection.amount) },
      },
    });
    return updated;
  });
  res.json({ data, paymentStatus: 'PAID', serverVerified: true });
});

financeRouter.post('/admin/cash-collections/:id/reject', admin, async (req: AuthRequest, res) => {
  const id = identifier.parse(req.params.id);
  const input = z.object({ reason: z.string().trim().min(5).max(1000) }).parse(req.body);
  const collection = await db.cashCollection.findFirst({
    where: { id, status: 'SUBMITTED', payment: { invoice: { businessId: tenant(req) } } },
    include: { technician: true },
  });
  if (!collection) throw new AppError(409, 'Cash collection is not awaiting verification', 'INVALID_CASH_TRANSITION');
  const data = await db.$transaction(async (tx) => {
    const updated = await tx.cashCollection.update({
      where: { id },
      data: { status: 'REJECTED', rejectionReason: input.reason },
    });
    await tx.payment.update({
      where: { id: collection.paymentId },
      data: { status: 'FAILED', failureReason: input.reason },
    });
    await tx.notification.create({
      data: {
        userId: collection.technician.userId,
        title: 'Cash receipt needs attention',
        body: input.reason,
        type: 'CASH_REJECTED',
      },
    });
    await tx.auditLog.create({
      data: {
        businessId: tenant(req),
        actorId: req.identity!.userId,
        action: 'CASH_COLLECTION_REJECTED',
        entity: 'CashCollection',
        entityId: id,
        metadata: { reason: input.reason },
      },
    });
    return updated;
  });
  res.json({ data });
});

financeRouter.get('/admin/settlements', admin, async (req: AuthRequest, res) => {
  const input = page.extend({
    status: z.enum(['PENDING', 'AVAILABLE', 'PAID', 'HELD', 'REVERSED']).optional(),
    technicianId: z.string().uuid().optional(),
  }).parse(req.query);
  const where = {
    businessId: tenant(req),
    ...(input.status ? { status: input.status } : {}),
    ...(input.technicianId ? { technicianId: input.technicianId } : {}),
  };
  const [data, total] = await db.$transaction([
    db.technicianLedger.findMany({
      where,
      skip: (input.page - 1) * input.limit,
      take: input.limit,
      orderBy: { createdAt: 'desc' },
      include: {
        technician: { include: { user: { select: { id: true, name: true, email: true } } } },
        payoutAllocations: { where: { releasedAt: null }, include: { payoutRequest: true } },
      },
    }),
    db.technicianLedger.count({ where }),
  ]);
  res.json({ data, meta: { page: input.page, limit: input.limit, total } });
});

financeRouter.patch('/admin/settlements/:id', admin, async (req: AuthRequest, res) => {
  const id = identifier.parse(req.params.id);
  const input = z.object({
    status: z.enum(['AVAILABLE', 'HELD', 'REVERSED']),
    reason: z.string().trim().max(1000).optional(),
  }).parse(req.body);
  if (['HELD', 'REVERSED'].includes(input.status) && !input.reason) {
    throw new AppError(422, 'A reason is required', 'REASON_REQUIRED');
  }
  const ledger = await db.technicianLedger.findFirst({
    where: { id, businessId: tenant(req) },
    include: { technician: true },
  });
  if (!ledger) throw new AppError(404, 'Settlement entry not found');
  const allowed: Record<string, string[]> = {
    PENDING: ['AVAILABLE', 'HELD', 'REVERSED'],
    AVAILABLE: ['HELD', 'REVERSED'],
    HELD: ['AVAILABLE', 'REVERSED'],
  };
  if (!allowed[ledger.status]?.includes(input.status)) {
    throw new AppError(409, `Settlement cannot move from ${ledger.status} to ${input.status}`, 'INVALID_SETTLEMENT_TRANSITION');
  }
  const activeAllocation = await db.payoutLedgerAllocation.findFirst({
    where: { ledgerId: id, releasedAt: null },
  });
  if (activeAllocation) {
    throw new AppError(409, 'Settlement is locked by an active payout request', 'SETTLEMENT_LOCKED');
  }
  if (input.status === 'AVAILABLE') {
    const job = await db.job.findFirst({
      where: {
        id: ledger.jobId,
        status: 'COMPLETED',
        booking: { businessId: tenant(req) },
      },
      include: {
        booking: {
          include: {
            invoice: {
              include: {
                payments: { include: { refunds: { where: { status: 'SUCCEEDED' } } } },
              },
            },
          },
        },
      },
    });
    const invoice = job?.booking.invoice;
    const verifiedNet = invoice?.payments.reduce((total, payment) => {
      if (!['PAID', 'REFUNDED'].includes(payment.status)) return total;
      const refunded = payment.refunds.reduce((sum, refund) => sum + Number(refund.amount), 0);
      return total + Number(payment.amount) - refunded;
    }, 0) ?? 0;
    if (!job || !invoice || verifiedNet + 0.000001 < Number(invoice.total)) {
      throw new AppError(409, 'Completed job and fully verified payment are required', 'SETTLEMENT_NOT_ELIGIBLE');
    }
    const unresolvedComplaint = await db.supportTicket.count({
      where: {
        businessId: tenant(req),
        status: { not: 'RESOLVED' },
        OR: [{ jobId: job.id }, { bookingId: job.bookingId }],
      },
    });
    if (unresolvedComplaint > 0) {
      throw new AppError(409, 'Settlement is blocked by an unresolved complaint', 'OPEN_COMPLAINT');
    }
  }
  const data = await db.$transaction(async (tx) => {
    const updated = await tx.technicianLedger.update({
      where: { id },
      data: {
        status: input.status,
        availableAt: input.status === 'AVAILABLE' ? new Date() : ledger.availableAt,
      },
    });
    await tx.notification.create({
      data: {
        userId: ledger.technician.userId,
        title: 'Earning status updated',
        body: `A settlement entry is now ${input.status.toLowerCase()}.`,
        type: 'SETTLEMENT_STATUS',
      },
    });
    await tx.auditLog.create({
      data: {
        businessId: tenant(req),
        actorId: req.identity!.userId,
        action: `SETTLEMENT_${input.status}`,
        entity: 'TechnicianLedger',
        entityId: id,
        metadata: { previousStatus: ledger.status, reason: input.reason },
      },
    });
    return updated;
  });
  res.json({ data });
});

financeRouter.get('/technician/payout-requests', technician, async (req: AuthRequest, res) => {
  const tech = await db.technician.findFirst({
    where: { userId: req.identity!.userId, businessId: tenant(req) },
  });
  if (!tech) throw new AppError(403, 'Technician profile required');
  const data = await db.payoutRequest.findMany({
    where: { businessId: tenant(req), technicianId: tech.id },
    orderBy: { requestedAt: 'desc' },
  });
  res.json({ data });
});

financeRouter.post('/technician/payout-requests', technician, async (req: AuthRequest, res) => {
  const idempotencyKey = requestKey(req, 'payout');
  const existing = await db.payoutRequest.findUnique({ where: { idempotencyKey } });
  if (existing) return void res.json({ data: existing, duplicate: true });
  const tech = await db.technician.findFirst({
    where: {
      userId: req.identity!.userId,
      businessId: tenant(req),
      verificationStatus: 'APPROVED',
    },
  });
  if (!tech) throw new AppError(403, 'Approved technician profile required', 'TECHNICIAN_NOT_APPROVED');
  const open = await db.payoutRequest.findFirst({
    where: {
      businessId: tenant(req),
      technicianId: tech.id,
      status: { in: ['REQUESTED', 'APPROVED', 'PROCESSING', 'FAILED'] },
    },
  });
  if (open) throw new AppError(409, 'Resolve the existing payout request first', 'PAYOUT_ALREADY_OPEN');
  const entries = await db.technicianLedger.findMany({
    where: { businessId: tenant(req), technicianId: tech.id, status: 'AVAILABLE' },
    orderBy: { availableAt: 'asc' },
  });
  if (entries.length === 0) throw new AppError(409, 'No available earnings to request', 'NO_AVAILABLE_EARNINGS');
  const amount = entries.reduce((sum, entry) => sum + Number(entry.netAmount), 0);
  const data = await db.$transaction(async (tx) => {
    const locked = await tx.technicianLedger.updateMany({
      where: { id: { in: entries.map((entry) => entry.id) }, status: 'AVAILABLE' },
      data: { status: 'HELD' },
    });
    if (locked.count !== entries.length) {
      throw new AppError(409, 'Earnings changed while creating the payout', 'PAYOUT_CONFLICT');
    }
    const payout = await tx.payoutRequest.create({
      data: {
        businessId: tenant(req),
        technicianId: tech.id,
        amount,
        requestedById: req.identity!.userId,
        idempotencyKey,
        allocations: {
          create: entries.map((entry) => ({ ledgerId: entry.id, amount: entry.netAmount })),
        },
      },
      include: { allocations: true },
    });
    const administrators = await tx.businessMember.findMany({
      where: {
        businessId: tenant(req),
        active: true,
        role: { name: { in: ['ADMIN', 'MANAGER', 'SUPER_ADMIN'] } },
        user: { status: 'ACTIVE', deletedAt: null },
      },
      select: { userId: true },
    });
    if (administrators.length > 0) {
      await tx.notification.createMany({
        data: administrators.map((member) => ({
          userId: member.userId,
          title: 'Payout approval required',
          body: `A technician requested a payout of ${amount.toFixed(2)}.`,
          type: 'PAYOUT_REQUESTED',
        })),
      });
    }
    await tx.auditLog.create({
      data: {
        businessId: tenant(req),
        actorId: req.identity!.userId,
        action: 'PAYOUT_REQUESTED',
        entity: 'PayoutRequest',
        entityId: payout.id,
        metadata: { amount, ledgerIds: entries.map((entry) => entry.id) },
      },
    });
    return payout;
  });
  res.status(201).json({ data });
});

financeRouter.get('/admin/payouts', admin, async (req: AuthRequest, res) => {
  const input = page.extend({
    status: z.enum(['REQUESTED', 'APPROVED', 'PROCESSING', 'PAID', 'FAILED', 'REJECTED']).optional(),
  }).parse(req.query);
  const where = {
    businessId: tenant(req),
    ...(input.status ? { status: input.status } : {}),
  };
  const [data, total] = await db.$transaction([
    db.payoutRequest.findMany({
      where,
      skip: (input.page - 1) * input.limit,
      take: input.limit,
      orderBy: { requestedAt: 'desc' },
      include: {
        technician: { include: { user: { select: { id: true, name: true, email: true, phone: true } } } },
        allocations: { include: { ledger: true } },
      },
    }),
    db.payoutRequest.count({ where }),
  ]);
  res.json({ data, meta: { page: input.page, limit: input.limit, total } });
});

financeRouter.post('/admin/payouts/:id/approve', admin, async (req: AuthRequest, res) => {
  const id = identifier.parse(req.params.id);
  const payout = await db.payoutRequest.findFirst({
    where: { id, businessId: tenant(req), status: 'REQUESTED' },
    include: { allocations: { where: { releasedAt: null } }, technician: true },
  });
  if (!payout || payout.allocations.length === 0) {
    throw new AppError(409, 'Payout is not eligible for approval', 'INVALID_PAYOUT_TRANSITION');
  }
  const data = await db.$transaction(async (tx) => {
    const updated = await tx.payoutRequest.update({
      where: { id },
      data: { status: 'APPROVED', approvedById: req.identity!.userId, approvedAt: new Date() },
    });
    await tx.notification.create({
      data: {
        userId: payout.technician.userId,
        title: 'Payout approved',
        body: 'Your payout request was approved and is waiting to be processed.',
        type: 'PAYOUT_APPROVED',
      },
    });
    await tx.auditLog.create({
      data: {
        businessId: tenant(req),
        actorId: req.identity!.userId,
        action: 'PAYOUT_APPROVED',
        entity: 'PayoutRequest',
        entityId: id,
      },
    });
    return updated;
  });
  res.json({ data });
});

financeRouter.post('/admin/payouts/:id/process', admin, async (req: AuthRequest, res) => {
  const id = identifier.parse(req.params.id);
  const payout = await db.payoutRequest.findFirst({
    where: { id, businessId: tenant(req), status: { in: ['APPROVED', 'FAILED'] } },
  });
  if (!payout) throw new AppError(409, 'Payout is not ready for processing', 'INVALID_PAYOUT_TRANSITION');
  const data = await db.$transaction(async (tx) => {
    const updated = await tx.payoutRequest.update({
      where: { id },
      data: { status: 'PROCESSING', processedById: req.identity!.userId, failureReason: null },
    });
    await tx.auditLog.create({
      data: {
        businessId: tenant(req),
        actorId: req.identity!.userId,
        action: 'PAYOUT_PROCESSING',
        entity: 'PayoutRequest',
        entityId: id,
        metadata: { previousStatus: payout.status },
      },
    });
    return updated;
  });
  res.json({ data, requiresExternalConfirmation: true });
});

financeRouter.post('/admin/payouts/:id/mark-paid', admin, async (req: AuthRequest, res) => {
  const id = identifier.parse(req.params.id);
  const input = z.object({
    reference: z.string().trim().min(6).max(200),
    confirmationSource: z.enum(['BANK_PORTAL', 'PAYMENT_PROVIDER', 'OFFLINE_TRANSFER']),
  }).parse(req.body);
  const payout = await db.payoutRequest.findFirst({
    where: { id, businessId: tenant(req), status: 'PROCESSING' },
    include: {
      technician: true,
      allocations: { where: { releasedAt: null }, include: { ledger: true } },
    },
  });
  if (!payout || payout.allocations.length === 0) {
    throw new AppError(409, 'Payout is not processing or has no locked earnings', 'INVALID_PAYOUT_TRANSITION');
  }
  if (payout.allocations.some((allocation) => allocation.ledger.status !== 'HELD')) {
    throw new AppError(409, 'One or more payout entries are no longer held', 'PAYOUT_LEDGER_MISMATCH');
  }
  const data = await db.$transaction(async (tx) => {
    const settled = await tx.technicianLedger.updateMany({
      where: {
        id: { in: payout.allocations.map((allocation) => allocation.ledgerId) },
        status: 'HELD',
      },
      data: { status: 'PAID' },
    });
    if (settled.count !== payout.allocations.length) {
      throw new AppError(409, 'Payout ledger changed during confirmation', 'PAYOUT_CONFLICT');
    }
    const updated = await tx.payoutRequest.update({
      where: { id },
      data: {
        status: 'PAID',
        reference: input.reference,
        processedById: req.identity!.userId,
        processedAt: new Date(),
        failureReason: null,
      },
    });
    await tx.notification.create({
      data: {
        userId: payout.technician.userId,
        title: 'Payout sent',
        body: `Your payout was confirmed with reference ${input.reference}.`,
        type: 'PAYOUT_PAID',
      },
    });
    await tx.auditLog.create({
      data: {
        businessId: tenant(req),
        actorId: req.identity!.userId,
        action: 'PAYOUT_PAID',
        entity: 'PayoutRequest',
        entityId: id,
        metadata: {
          reference: input.reference,
          confirmationSource: input.confirmationSource,
          ledgerIds: payout.allocations.map((allocation) => allocation.ledgerId),
        },
      },
    });
    return updated;
  });
  res.json({ data, serverRecorded: true });
});

financeRouter.post('/admin/payouts/:id/fail', admin, async (req: AuthRequest, res) => {
  const id = identifier.parse(req.params.id);
  const input = z.object({ reason: z.string().trim().min(5).max(1000) }).parse(req.body);
  const payout = await db.payoutRequest.findFirst({
    where: { id, businessId: tenant(req), status: 'PROCESSING' },
    include: { technician: true },
  });
  if (!payout) throw new AppError(409, 'Only a processing payout can fail', 'INVALID_PAYOUT_TRANSITION');
  const data = await db.$transaction(async (tx) => {
    const updated = await tx.payoutRequest.update({
      where: { id },
      data: { status: 'FAILED', failureReason: input.reason, processedById: req.identity!.userId },
    });
    await tx.notification.create({
      data: {
        userId: payout.technician.userId,
        title: 'Payout delayed',
        body: input.reason,
        type: 'PAYOUT_FAILED',
      },
    });
    await tx.auditLog.create({
      data: {
        businessId: tenant(req),
        actorId: req.identity!.userId,
        action: 'PAYOUT_FAILED',
        entity: 'PayoutRequest',
        entityId: id,
        metadata: { reason: input.reason },
      },
    });
    return updated;
  });
  res.json({ data });
});

financeRouter.post('/admin/payouts/:id/reject', admin, async (req: AuthRequest, res) => {
  const id = identifier.parse(req.params.id);
  const input = z.object({ reason: z.string().trim().min(5).max(1000) }).parse(req.body);
  const payout = await db.payoutRequest.findFirst({
    where: {
      id,
      businessId: tenant(req),
      status: { in: ['REQUESTED', 'APPROVED', 'FAILED'] },
    },
    include: {
      technician: true,
      allocations: { where: { releasedAt: null }, include: { ledger: true } },
    },
  });
  if (!payout) throw new AppError(409, 'Payout cannot be rejected in its current state', 'INVALID_PAYOUT_TRANSITION');
  const data = await db.$transaction(async (tx) => {
    const ledgerIds = payout.allocations.map((allocation) => allocation.ledgerId);
    if (ledgerIds.length > 0) {
      await tx.technicianLedger.updateMany({
        where: { id: { in: ledgerIds }, status: 'HELD' },
        data: { status: 'AVAILABLE' },
      });
      await tx.payoutLedgerAllocation.updateMany({
        where: { payoutRequestId: id, releasedAt: null },
        data: { releasedAt: new Date() },
      });
    }
    const updated = await tx.payoutRequest.update({
      where: { id },
      data: { status: 'REJECTED', failureReason: input.reason, processedAt: new Date() },
    });
    await tx.notification.create({
      data: {
        userId: payout.technician.userId,
        title: 'Payout request rejected',
        body: input.reason,
        type: 'PAYOUT_REJECTED',
      },
    });
    await tx.auditLog.create({
      data: {
        businessId: tenant(req),
        actorId: req.identity!.userId,
        action: 'PAYOUT_REJECTED',
        entity: 'PayoutRequest',
        entityId: id,
        metadata: { reason: input.reason, releasedLedgerIds: ledgerIds },
      },
    });
    return updated;
  });
  res.json({ data });
});
