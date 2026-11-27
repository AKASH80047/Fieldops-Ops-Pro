import { beforeEach, describe, expect, it, vi } from 'vitest';
import request from 'supertest';

const mocks = vi.hoisted(() => ({
  customerFindFirst: vi.fn(),
  serviceFindFirst: vi.fn(),
  addressFindFirst: vi.fn(),
  transaction: vi.fn(),
  tx: {
    booking: { create: vi.fn() },
    auditLog: { create: vi.fn() },
    technician: { findMany: vi.fn() },
    notification: { createMany: vi.fn() },
  },
}));

vi.mock('./db.js', () => ({
  db: {
    customer: { findFirst: mocks.customerFindFirst },
    service: { findFirst: mocks.serviceFindFirst },
    address: { findFirst: mocks.addressFindFirst },
    $transaction: mocks.transaction,
  },
}));

import { app } from './app.js';
import { signAccess } from './security.js';

const businessId = 'f07de076-8e61-4268-bf0b-d2b0856c738c';
const customerId = '657b8f3e-dd36-47f1-a67b-9ff27c664fbe';
const serviceId = '98746e1c-5d8d-468b-b006-f976e0e8e615';
const addressId = 'f8459659-6f30-436f-8982-a5489069feb1';
const token = signAccess({
  userId: 'customer-user-1',
  businessId,
  role: 'CUSTOMER',
  permissions: [],
});

describe('booking opportunity notifications', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.transaction.mockImplementation(
      async (operation: (tx: typeof mocks.tx) => unknown) => operation(mocks.tx),
    );
    mocks.customerFindFirst.mockResolvedValue({ id: customerId });
    mocks.serviceFindFirst.mockResolvedValue({
      id: serviceId,
      name: 'Cooking service',
      basePrice: 1000,
      taxRate: 0,
      requiredSkills: ['Cook'],
      coverage: [
        {
          active: true,
          serviceAreaId: '73ffb4a2-534c-4c31-bd05-698f5a207b44',
          serviceArea: { active: true, postalCodes: ['110001'] },
        },
      ],
    });
    mocks.addressFindFirst.mockResolvedValue({
      id: addressId,
      postalCode: '110001',
      city: 'New Delhi',
    });
    mocks.tx.booking.create.mockResolvedValue({
      id: 'booking-1',
      job: { id: 'job-1' },
      invoice: { id: 'invoice-1', items: [] },
    });
    mocks.tx.auditLog.create.mockResolvedValue({});
    mocks.tx.notification.createMany.mockResolvedValue({ count: 1 });
  });

  it('notifies only approved online technicians whose skill, area and eKYC match', async () => {
    mocks.tx.technician.findMany.mockResolvedValue([
      {
        id: 'eligible',
        userId: 'eligible-user',
        skills: ['Cook', 'Cleaner'],
        documents: [
          { type: 'IDENTITY', status: 'APPROVED' },
          { type: 'ADDRESS', status: 'APPROVED' },
          { type: 'LIVE_SELFIE', status: 'APPROVED' },
        ],
      },
      {
        id: 'wrong-skill',
        userId: 'wrong-skill-user',
        skills: ['Electrician'],
        documents: [
          { type: 'IDENTITY', status: 'APPROVED' },
          { type: 'ADDRESS', status: 'APPROVED' },
          { type: 'LIVE_SELFIE', status: 'APPROVED' },
        ],
      },
      {
        id: 'incomplete-ekyc',
        userId: 'incomplete-user',
        skills: ['Cook'],
        documents: [{ type: 'IDENTITY', status: 'APPROVED' }],
      },
    ]);

    const response = await request(app)
      .post('/api/v1/bookings')
      .set('Authorization', `Bearer ${token}`)
      .send({
        serviceId,
        addressId,
        scheduledAt: new Date(Date.now() + 86_400_000).toISOString(),
      });

    expect(response.status).toBe(201);
    expect(mocks.tx.technician.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          businessId,
          verificationStatus: 'APPROVED',
          available: true,
        }),
      }),
    );
    expect(mocks.tx.notification.createMany).toHaveBeenCalledWith({
      data: [
        {
          userId: 'eligible-user',
          title: 'New nearby job',
          body: 'Cooking service is available in New Delhi.',
          type: 'JOB_OPPORTUNITY',
        },
      ],
    });
  });
});
