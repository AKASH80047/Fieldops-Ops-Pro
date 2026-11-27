import { describe, expect, it } from 'vitest';
import request from 'supertest';
import { app } from './app.js';
import { signAccess } from './security.js';

const adminOnlyRequests = [
  () => request(app).get('/api/v1/admin/dashboard'),
  () => request(app).get('/api/v1/admin/technicians'),
  () =>
    request(app)
      .patch('/api/v1/admin/technicians/technician-1/verification')
      .send({ status: 'UNDER_REVIEW' }),
  () => request(app).get('/api/v1/admin/customers'),
  () => request(app).get('/api/v1/admin/jobs'),
  () => request(app).get('/api/v1/admin/service-categories'),
  () => request(app).get('/api/v1/admin/services'),
  () => request(app).get('/api/v1/admin/complaints'),
  () => request(app).get('/api/v1/admin/payments'),
  () => request(app).get('/api/v1/admin/refunds'),
  () => request(app).get('/api/v1/admin/cash-collections'),
  () => request(app).get('/api/v1/admin/settlements'),
  () => request(app).get('/api/v1/admin/payouts'),
  () =>
    request(app)
      .post('/api/v1/admin/jobs/job-1/assign-technician')
      .send({ technicianId: '8ee155ab-bdd8-4050-a410-f73ea0a06859' }),
] as const;

describe('admin API role boundary', () => {
  for (const role of ['CUSTOMER', 'TECHNICIAN']) {
    it(`rejects every admin operation for the ${role} role`, async () => {
      const token = signAccess({
        userId: `${role.toLowerCase()}-1`,
        businessId: 'business-1',
        role,
        permissions: [],
      });

      for (const buildRequest of adminOnlyRequests) {
        const response = await buildRequest().set(
          'Authorization',
          `Bearer ${token}`,
        );

        expect(response.status).toBe(403);
        expect(response.body.error.code).toBe('FORBIDDEN');
      }
    });
  }

  it('rejects a signed identity that has no selected business', async () => {
    const token = signAccess({
      userId: 'admin-1',
      businessId: '',
      role: 'ADMIN',
      permissions: [],
    });

    const response = await request(app)
      .get('/api/v1/admin/dashboard')
      .set('Authorization', `Bearer ${token}`);

    expect(response.status).toBe(403);
    expect(response.body.error.code).toBe('TENANT_REQUIRED');
  });
});
