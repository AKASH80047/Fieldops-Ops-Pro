import { Router } from 'express';
import { z } from 'zod';
import { db } from './db.js';
import { AppError } from './errors.js';
import { allow } from './middleware.js';
import type { AuthRequest } from './types.js';

export const adminAnalyticsRouter = Router();
adminAnalyticsRouter.use(allow('ADMIN', 'MANAGER', 'SUPER_ADMIN'));

const dayMs = 24 * 60 * 60 * 1000;
const querySchema = z.object({
  from: z.string().trim().max(40).optional(),
  to: z.string().trim().max(40).optional(),
  granularity: z.enum(['day', 'month']).default('day'),
});

function parseBoundary(value: string | undefined, end: boolean, fallback: Date) {
  if (!value) return fallback;
  const dateOnly = /^\d{4}-\d{2}-\d{2}$/.test(value);
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new AppError(422, `${end ? 'to' : 'from'} must be an ISO date`, 'INVALID_DATE_RANGE');
  }
  if (dateOnly) {
    date.setUTCHours(end ? 23 : 0, end ? 59 : 0, end ? 59 : 0, end ? 999 : 0);
  }
  return date;
}

function periodKey(date: Date, granularity: 'day' | 'month') {
  const iso = date.toISOString();
  return granularity === 'day' ? iso.slice(0, 10) : iso.slice(0, 7);
}

function seedPeriods<T>(
  from: Date,
  to: Date,
  granularity: 'day' | 'month',
  create: (period: string) => T,
) {
  const values = new Map<string, T>();
  const cursor = new Date(from);
  if (granularity === 'day') {
    cursor.setUTCHours(0, 0, 0, 0);
  } else {
    cursor.setUTCDate(1);
    cursor.setUTCHours(0, 0, 0, 0);
  }
  while (cursor <= to) {
    const key = periodKey(cursor, granularity);
    values.set(key, create(key));
    if (granularity === 'day') cursor.setUTCDate(cursor.getUTCDate() + 1);
    else cursor.setUTCMonth(cursor.getUTCMonth() + 1);
  }
  return values;
}

adminAnalyticsRouter.get('/', async (req: AuthRequest, res) => {
  const input = querySchema.parse(req.query);
  const now = new Date();
  const defaultFrom = new Date(now.getTime() - 29 * dayMs);
  defaultFrom.setUTCHours(0, 0, 0, 0);
  const from = parseBoundary(input.from, false, defaultFrom);
  const to = parseBoundary(input.to, true, now);
  if (from > to || to.getTime() - from.getTime() > 366 * dayMs) {
    throw new AppError(
      422,
      'Analytics range must be ordered and no longer than 366 days',
      'INVALID_DATE_RANGE',
    );
  }

  const businessId = req.identity!.businessId;
  const [payments, refunds, bookings, completedJobs, cancelledBookings, technicians] =
    await db.$transaction([
      db.payment.findMany({
        where: {
          currency: 'INR',
          status: { in: ['PAID', 'REFUNDED'] },
          verifiedAt: { gte: from, lte: to },
          invoice: { businessId },
        },
        select: {
          amount: true,
          verifiedAt: true,
          invoice: {
            select: {
              booking: {
                select: {
                  service: { select: { category: { select: { id: true, name: true } } } },
                },
              },
            },
          },
        },
      }),
      db.refund.findMany({
        where: {
          status: 'SUCCEEDED',
          processedAt: { gte: from, lte: to },
          payment: { invoice: { businessId } },
        },
        select: {
          amount: true,
          processedAt: true,
          payment: {
            select: {
              invoice: {
                select: {
                  booking: {
                    select: {
                      service: { select: { category: { select: { id: true, name: true } } } },
                    },
                  },
                },
              },
            },
          },
        },
      }),
      db.booking.findMany({
        where: { businessId, deletedAt: null, createdAt: { gte: from, lte: to } },
        select: {
          id: true,
          status: true,
          createdAt: true,
          service: { select: { category: { select: { id: true, name: true } } } },
        },
      }),
      db.job.findMany({
        where: {
          status: 'COMPLETED',
          completedAt: { gte: from, lte: to },
          booking: { businessId },
        },
        select: {
          id: true,
          completedAt: true,
          booking: {
            select: {
              service: { select: { category: { select: { id: true, name: true } } } },
            },
          },
        },
      }),
      db.booking.findMany({
        where: {
          businessId,
          deletedAt: null,
          status: 'CANCELLED',
          updatedAt: { gte: from, lte: to },
        },
        select: { id: true, updatedAt: true },
      }),
      db.technician.findMany({
        where: { businessId },
        select: {
          id: true,
          rating: true,
          verificationStatus: true,
          user: { select: { name: true } },
          assignments: {
            where: {
              unassignedAt: null,
              job: {
                status: 'COMPLETED',
                completedAt: { gte: from, lte: to },
                booking: { businessId },
              },
            },
            select: { id: true },
          },
          ledgerEntries: {
            where: { businessId, createdAt: { gte: from, lte: to } },
            select: {
              grossAmount: true,
              commissionAmount: true,
              netAmount: true,
              status: true,
            },
          },
        },
      }),
    ]);

  const revenue = seedPeriods(from, to, input.granularity, (period) => ({
    period,
    grossPayments: 0,
    refunds: 0,
    netRevenue: 0,
  }));
  const bookingTrend = seedPeriods(from, to, input.granularity, (period) => ({
    period,
    total: 0,
    statuses: {} as Record<string, number>,
  }));
  const monthly = seedPeriods(from, to, 'month', (period) => ({
    period,
    bookings: 0,
    completedJobs: 0,
    cancelledBookings: 0,
    grossPayments: 0,
    refunds: 0,
    netRevenue: 0,
  }));
  const categories = new Map<
    string,
    {
      categoryId: string;
      category: string;
      bookings: number;
      completedJobs: number;
      grossPayments: number;
      refunds: number;
      netRevenue: number;
    }
  >();
  const category = (id: string, name: string) => {
    const existing = categories.get(id);
    if (existing) return existing;
    const created = {
      categoryId: id,
      category: name,
      bookings: 0,
      completedJobs: 0,
      grossPayments: 0,
      refunds: 0,
      netRevenue: 0,
    };
    categories.set(id, created);
    return created;
  };

  for (const payment of payments) {
    if (!payment.verifiedAt) continue;
    const amount = Number(payment.amount);
    const bucket = revenue.get(periodKey(payment.verifiedAt, input.granularity));
    if (bucket) {
      bucket.grossPayments += amount;
      bucket.netRevenue += amount;
    }
    const month = monthly.get(periodKey(payment.verifiedAt, 'month'));
    if (month) {
      month.grossPayments += amount;
      month.netRevenue += amount;
    }
    const value = payment.invoice.booking.service.category;
    const row = category(value.id, value.name);
    row.grossPayments += amount;
    row.netRevenue += amount;
  }
  for (const refund of refunds) {
    if (!refund.processedAt) continue;
    const amount = Number(refund.amount);
    const bucket = revenue.get(periodKey(refund.processedAt, input.granularity));
    if (bucket) {
      bucket.refunds += amount;
      bucket.netRevenue -= amount;
    }
    const month = monthly.get(periodKey(refund.processedAt, 'month'));
    if (month) {
      month.refunds += amount;
      month.netRevenue -= amount;
    }
    const value = refund.payment.invoice.booking.service.category;
    const row = category(value.id, value.name);
    row.refunds += amount;
    row.netRevenue -= amount;
  }
  for (const booking of bookings) {
    const bucket = bookingTrend.get(periodKey(booking.createdAt, input.granularity));
    if (bucket) {
      bucket.total += 1;
      bucket.statuses[booking.status] = (bucket.statuses[booking.status] ?? 0) + 1;
    }
    const month = monthly.get(periodKey(booking.createdAt, 'month'));
    if (month) month.bookings += 1;
    const value = booking.service.category;
    category(value.id, value.name).bookings += 1;
  }
  for (const job of completedJobs) {
    if (!job.completedAt) continue;
    const month = monthly.get(periodKey(job.completedAt, 'month'));
    if (month) month.completedJobs += 1;
    const value = job.booking.service.category;
    category(value.id, value.name).completedJobs += 1;
  }
  for (const booking of cancelledBookings) {
    const month = monthly.get(periodKey(booking.updatedAt, 'month'));
    if (month) month.cancelledBookings += 1;
  }

  const technicianPerformance = technicians
    .map((technician) => ({
      technicianId: technician.id,
      name: technician.user.name,
      verificationStatus: technician.verificationStatus,
      rating: Number(technician.rating),
      completedJobs: technician.assignments.length,
      grossEarnings: technician.ledgerEntries.reduce(
        (total, entry) => total + Number(entry.grossAmount),
        0,
      ),
      commission: technician.ledgerEntries.reduce(
        (total, entry) => total + Number(entry.commissionAmount),
        0,
      ),
      netEarnings: technician.ledgerEntries.reduce(
        (total, entry) => total + Number(entry.netAmount),
        0,
      ),
      unsettledEntries: technician.ledgerEntries.filter((entry) =>
        ['PENDING', 'AVAILABLE', 'HELD'].includes(entry.status),
      ).length,
    }))
    .sort((a, b) => b.completedJobs - a.completedJobs || b.netEarnings - a.netEarnings)
    .slice(0, 20);

  res.json({
    data: {
      currency: 'INR',
      revenueSeries: [...revenue.values()],
      bookingTrend: [...bookingTrend.values()],
      monthlyPerformance: [...monthly.values()],
      categoryPerformance: [...categories.values()].sort(
        (a, b) => b.bookings - a.bookings || b.netRevenue - a.netRevenue,
      ),
      technicianPerformance,
    },
    meta: {
      from: from.toISOString(),
      to: to.toISOString(),
      granularity: input.granularity,
      timezone: 'UTC',
      technicianLimit: 20,
    },
  });
});
