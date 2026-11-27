import { Router } from 'express';
import { z } from 'zod';
import { db } from './db.js';
import { AppError } from './errors.js';
import { allow } from './middleware.js';
import type { AuthRequest } from './types.js';

export const adminCustomerRouter = Router();
adminCustomerRouter.use(allow('ADMIN', 'MANAGER', 'SUPER_ADMIN'));

const identifier = z.string().uuid();
const detailQuery = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  relatedLimit: z.coerce.number().int().min(1).max(50).default(20),
});

function tenant(req: AuthRequest) {
  return req.identity!.businessId;
}

adminCustomerRouter.get('/customers/:id', async (req: AuthRequest, res) => {
  const id = identifier.parse(req.params.id);
  const input = detailQuery.parse(req.query);
  const customer = await db.customer.findFirst({
    where: { id, businessId: tenant(req) },
    select: {
      id: true,
      businessId: true,
      notes: true,
      user: {
        select: {
          id: true,
          name: true,
          email: true,
          phone: true,
          status: true,
          createdAt: true,
          updatedAt: true,
        },
      },
      addresses: {
        orderBy: { updatedAt: 'desc' },
        select: {
          id: true,
          label: true,
          line1: true,
          line2: true,
          city: true,
          state: true,
          postalCode: true,
          latitude: true,
          longitude: true,
          createdAt: true,
          updatedAt: true,
        },
      },
    },
  });
  if (!customer) throw new AppError(404, 'Customer not found');

  const bookingWhere = {
    businessId: tenant(req),
    customerId: customer.id,
    deletedAt: null,
  };
  const invoiceWhere = {
    businessId: tenant(req),
    booking: { customerId: customer.id },
  };
  const reviewWhere = {
    booking: { businessId: tenant(req), customerId: customer.id },
  };
  const ticketWhere = {
    businessId: tenant(req),
    customerId: customer.id,
  };

  const [
    bookings,
    bookingTotal,
    invoices,
    invoiceTotal,
    reviews,
    reviewTotal,
    complaints,
    complaintTotal,
  ] = await db.$transaction([
    db.booking.findMany({
      where: bookingWhere,
      skip: (input.page - 1) * input.limit,
      take: input.limit,
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        status: true,
        scheduledAt: true,
        instructions: true,
        estimatedPrice: true,
        finalPrice: true,
        cancelledReason: true,
        createdAt: true,
        updatedAt: true,
        service: {
          select: {
            id: true,
            name: true,
            description: true,
            basePrice: true,
            durationMinutes: true,
            category: { select: { id: true, name: true } },
          },
        },
        address: {
          select: {
            id: true,
            label: true,
            line1: true,
            line2: true,
            city: true,
            state: true,
            postalCode: true,
          },
        },
        job: {
          select: {
            id: true,
            status: true,
            priority: true,
            startedAt: true,
            completedAt: true,
            createdAt: true,
            updatedAt: true,
            report: {
              select: {
                id: true,
                description: true,
                summary: true,
                additionalCharge: true,
                submittedAt: true,
              },
            },
            assignments: {
              where: { unassignedAt: null },
              select: {
                assignedAt: true,
                technician: {
                  select: {
                    id: true,
                    rating: true,
                    user: { select: { id: true, name: true, phone: true } },
                  },
                },
              },
            },
          },
        },
      },
    }),
    db.booking.count({ where: bookingWhere }),
    db.invoice.findMany({
      where: invoiceWhere,
      take: input.relatedLimit,
      orderBy: { issuedAt: 'desc' },
      select: {
        id: true,
        bookingId: true,
        number: true,
        subtotal: true,
        tax: true,
        total: true,
        status: true,
        issuedAt: true,
        dueAt: true,
        items: {
          select: {
            id: true,
            description: true,
            quantity: true,
            unitPrice: true,
            tax: true,
          },
        },
        payments: {
          orderBy: { createdAt: 'desc' },
          select: {
            id: true,
            provider: true,
            method: true,
            currency: true,
            amount: true,
            status: true,
            verifiedAt: true,
            createdAt: true,
            updatedAt: true,
            refunds: {
              orderBy: { createdAt: 'desc' },
              select: {
                id: true,
                amount: true,
                status: true,
                reason: true,
                failureReason: true,
                createdAt: true,
                updatedAt: true,
                processedAt: true,
              },
            },
            cashCollection: {
              select: {
                id: true,
                amount: true,
                status: true,
                collectedAt: true,
                submittedAt: true,
                verifiedAt: true,
                rejectionReason: true,
              },
            },
          },
        },
      },
    }),
    db.invoice.count({ where: invoiceWhere }),
    db.review.findMany({
      where: reviewWhere,
      take: input.relatedLimit,
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        rating: true,
        comment: true,
        createdAt: true,
        user: { select: { id: true, name: true } },
        booking: {
          select: {
            id: true,
            service: { select: { id: true, name: true } },
          },
        },
      },
    }),
    db.review.count({ where: reviewWhere }),
    db.supportTicket.findMany({
      where: ticketWhere,
      take: input.relatedLimit,
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        bookingId: true,
        jobId: true,
        technicianId: true,
        subject: true,
        description: true,
        status: true,
        priority: true,
        assignedToId: true,
        adminNotes: true,
        resolution: true,
        resolvedAt: true,
        reopenedAt: true,
        createdAt: true,
        updatedAt: true,
        booking: {
          select: {
            id: true,
            service: { select: { id: true, name: true } },
          },
        },
        technician: {
          select: {
            id: true,
            user: { select: { id: true, name: true } },
          },
        },
      },
    }),
    db.supportTicket.count({ where: ticketWhere }),
  ]);

  res.json({
    data: { ...customer, bookings, invoices, reviews, complaints },
    meta: {
      bookings: { page: input.page, limit: input.limit, total: bookingTotal },
      invoices: { limit: input.relatedLimit, total: invoiceTotal },
      reviews: { limit: input.relatedLimit, total: reviewTotal },
      complaints: { limit: input.relatedLimit, total: complaintTotal },
    },
  });
});

adminCustomerRouter.patch('/customers/:id/notes', async (req: AuthRequest, res) => {
  const id = identifier.parse(req.params.id);
  const input = z.object({
    notes: z.string().trim().max(5000).nullable(),
  }).parse(req.body);
  const customer = await db.customer.findFirst({
    where: { id, businessId: tenant(req) },
    select: { id: true, notes: true },
  });
  if (!customer) throw new AppError(404, 'Customer not found');

  const normalizedNotes = input.notes?.length ? input.notes : null;
  const data = await db.$transaction(async (tx) => {
    const updated = await tx.customer.update({
      where: { id },
      data: { notes: normalizedNotes },
      select: { id: true, notes: true },
    });
    await tx.auditLog.create({
      data: {
        businessId: tenant(req),
        actorId: req.identity!.userId,
        action: 'CUSTOMER_NOTES_UPDATED',
        entity: 'Customer',
        entityId: id,
        metadata: {
          cleared: normalizedNotes === null,
          previousLength: customer.notes?.length ?? 0,
          currentLength: normalizedNotes?.length ?? 0,
        },
      },
    });
    return updated;
  });
  res.json({ data });
});
