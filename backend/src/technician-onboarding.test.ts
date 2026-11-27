import { beforeEach, describe, expect, it, vi } from 'vitest';
import request from 'supertest';

const mocks = vi.hoisted(() => ({
  technicianFindFirst: vi.fn(),
  jobFindMany: vi.fn(),
  transaction: vi.fn(),
  tx: {
    user: { update: vi.fn() },
    technician: { findFirst: vi.fn(), update: vi.fn() },
    serviceArea: { findMany: vi.fn() },
    technicianServiceArea: { updateMany: vi.fn(), createMany: vi.fn() },
    job: { findFirst: vi.fn(), update: vi.fn() },
    booking: { update: vi.fn() },
    jobAssignment: { findMany: vi.fn(), create: vi.fn() },
    jobStatusHistory: { create: vi.fn() },
    notification: { createMany: vi.fn() },
    auditLog: { create: vi.fn() },
    $queryRaw: vi.fn(),
  },
}));

vi.mock('./db.js', () => ({
  db: {
    technician: { findFirst: mocks.technicianFindFirst },
    job: { findMany: mocks.jobFindMany },
    $transaction: mocks.transaction,
  },
}));

import { app } from './app.js';
import { signAccess } from './security.js';

const businessId = '0a5b0f9a-25f0-4acb-a81a-76cc4523a15a';
const technicianId = 'dc02eb4a-bd63-4cf6-8478-e63ef13a6c73';
const userId = 'technician-user-1';
const jobId = 'a66bdce2-6cd8-4105-8611-ad3d38df927d';
const serviceAreaId = '5e335bcb-ac51-4542-ab06-ac07f48677af';
const token = signAccess({
  userId,
  businessId,
  role: 'TECHNICIAN',
  permissions: [],
});

const approvedDocuments = [
  { type: 'IDENTITY', status: 'APPROVED' },
  { type: 'ADDRESS', status: 'APPROVED' },
  { type: 'LIVE_SELFIE', status: 'APPROVED' },
];

function eligibleTechnician() {
  return {
    id: technicianId,
    userId,
    businessId,
    skills: ['Electrician'],
    experienceYears: 4,
    rating: 4.8,
    available: true,
    verificationStatus: 'APPROVED',
    profileCompletedAt: new Date(),
    locationLat: 28.6139,
    locationLng: 77.209,
    documents: approvedDocuments,
    serviceAreas: [
      {
        serviceAreaId,
        active: true,
        serviceArea: {
          id: serviceAreaId,
          active: true,
          postalCodes: ['110001'],
        },
      },
    ],
  };
}

function opportunity() {
  return {
    id: jobId,
    bookingId: 'booking-1',
    status: 'PENDING',
    priority: 'NORMAL',
    booking: {
      customerId: 'customer-1',
      scheduledAt: new Date(Date.now() + 86_400_000),
      estimatedPrice: 799,
      customer: { userId: 'customer-user-1' },
      service: {
        id: 'service-1',
        name: 'Electrical inspection',
        durationMinutes: 60,
        requiredSkills: ['electrician'],
        category: { name: 'Electrical' },
        coverage: [{ serviceAreaId }],
      },
      address: {
        line1: 'Private house number and street',
        line2: 'Private landmark',
        city: 'New Delhi',
        state: 'Delhi',
        postalCode: '110001',
        latitude: 28.614,
        longitude: 77.21,
      },
    },
  };
}

describe('technician onboarding and opportunity boundaries', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.transaction.mockImplementation(
      async (operation: (tx: typeof mocks.tx) => unknown) => operation(mocks.tx),
    );
    mocks.tx.serviceArea.findMany.mockResolvedValue([]);
  });

  it('hashes Aadhaar server-side and never returns or audits the raw value', async () => {
    mocks.technicianFindFirst.mockResolvedValue({
      id: technicianId,
      userId,
      businessId,
      verificationStatus: 'DRAFT',
      aadhaarHash: null,
    });
    mocks.tx.user.update.mockResolvedValue({});
    mocks.tx.technician.update.mockImplementation(async ({ data }) => ({
      ...eligibleTechnician(),
      ...data,
      user: {
        id: userId,
        name: 'Ravi Kumar',
        email: 'ravi@example.com',
        phone: '9876543210',
        status: 'ACTIVE',
      },
      addressLine1: data.addressLine1,
      documents: [],
      serviceAreas: [],
    }));
    mocks.tx.auditLog.create.mockResolvedValue({});

    const rawAadhaar = '1234 5678 9012';
    const response = await request(app)
      .patch('/api/v1/technician/application')
      .set('Authorization', `Bearer ${token}`)
      .send({
        name: 'Ravi Kumar',
        phone: '9876543210',
        skills: ['Electrician'],
        experienceYears: 4,
        address: {
          line1: '10 Main Road',
          city: 'New Delhi',
          state: 'Delhi',
          postalCode: '110001',
        },
        aadhaarNumber: rawAadhaar,
        aadhaarConsent: true,
      });

    expect(response.status).toBe(200);
    expect(response.body.data.aadhaarMasked).toBe('XXXXXXXX9012');
    expect(JSON.stringify(response.body)).not.toContain('123456789012');
    expect(response.body.data).not.toHaveProperty('aadhaarHash');
    const persisted = mocks.tx.technician.update.mock.calls[0][0].data;
    expect(persisted.aadhaarLast4).toBe('9012');
    expect(persisted.aadhaarHash).toMatch(/^[a-f0-9]{64}$/);
    expect(persisted.aadhaarHash).not.toContain('123456789012');
    expect(JSON.stringify(mocks.tx.auditLog.create.mock.calls)).not.toContain('123456789012');
  });

  it('returns only matching nearby work with customer identity and exact address redacted', async () => {
    mocks.technicianFindFirst.mockResolvedValue(eligibleTechnician());
    mocks.jobFindMany.mockResolvedValue([opportunity()]);

    const response = await request(app)
      .get('/api/v1/technician/opportunities')
      .set('Authorization', `Bearer ${token}`);

    expect(response.status).toBe(200);
    expect(response.body.data).toHaveLength(1);
    expect(response.body.data[0]).toMatchObject({
      id: jobId,
      service: { name: 'Electrical inspection', category: 'Electrical' },
      area: { city: 'New Delhi', state: 'Delhi', postalCode: '110001' },
    });
    const serialized = JSON.stringify(response.body);
    expect(serialized).not.toContain('customer-user-1');
    expect(serialized).not.toContain('Private house number and street');
    expect(serialized).not.toContain('Private landmark');
    expect(mocks.technicianFindFirst).toHaveBeenCalledWith(
      expect.objectContaining({ where: { userId, businessId } }),
    );
  });

  it('claims an eligible job in a serializable transaction', async () => {
    mocks.tx.technician.findFirst.mockResolvedValue(eligibleTechnician());
    mocks.tx.$queryRaw.mockResolvedValue([{ id: jobId }]);
    mocks.tx.job.findFirst.mockResolvedValue(opportunity());
    mocks.tx.jobAssignment.findMany.mockResolvedValue([]);
    mocks.tx.jobAssignment.create.mockResolvedValue({
      id: 'assignment-1',
      jobId,
      technicianId,
    });
    mocks.tx.job.update.mockResolvedValue({ id: jobId, status: 'ASSIGNED' });
    mocks.tx.booking.update.mockResolvedValue({});
    mocks.tx.jobStatusHistory.create.mockResolvedValue({});
    mocks.tx.notification.createMany.mockResolvedValue({ count: 2 });
    mocks.tx.auditLog.create.mockResolvedValue({});

    const response = await request(app)
      .post(`/api/v1/technician/opportunities/${jobId}/claim`)
      .set('Authorization', `Bearer ${token}`)
      .send();

    expect(response.status).toBe(201);
    expect(response.body.data.job.status).toBe('ASSIGNED');
    expect(mocks.transaction).toHaveBeenCalledWith(
      expect.any(Function),
      { isolationLevel: 'Serializable' },
    );
    expect(mocks.tx.jobAssignment.create).toHaveBeenCalledWith({
      data: { jobId, technicianId },
    });
    expect(mocks.tx.notification.createMany).toHaveBeenCalledWith({
      data: expect.arrayContaining([
        expect.objectContaining({ userId: 'customer-user-1' }),
        expect.objectContaining({ userId }),
      ]),
    });
  });

  it('reports submitted work awaiting customer approval in technician progress', async () => {
    mocks.technicianFindFirst.mockResolvedValue({
      id: technicianId,
      verificationStatus: 'APPROVED',
      profileCompletedAt: new Date(),
      available: true,
      rating: 4.8,
      documents: approvedDocuments,
      assignments: [
        { job: { status: 'IN_PROGRESS' } },
        { job: { status: 'COMPLETED' } },
      ],
      ledgerEntries: [
        {
          grossAmount: 1000,
          netAmount: 800,
          status: 'AVAILABLE',
        },
      ],
      workReports: [
        {
          id: 'report-awaiting-approval',
          submittedAt: new Date(),
          job: { status: 'IN_PROGRESS' },
        },
        {
          id: 'approved-report',
          submittedAt: new Date(),
          job: { status: 'COMPLETED' },
        },
      ],
    });

    const response = await request(app)
      .get('/api/v1/technician/progress')
      .set('Authorization', `Bearer ${token}`);

    expect(response.status).toBe(200);
    expect(response.body.data.jobs).toMatchObject({
      total: 2,
      active: 1,
      completed: 1,
      completionRate: 50,
      reportsSubmitted: 2,
      pendingApprovals: 1,
    });
    expect(response.body.data.earnings).toMatchObject({
      gross: 1000,
      net: 800,
      available: 800,
    });
  });
});
