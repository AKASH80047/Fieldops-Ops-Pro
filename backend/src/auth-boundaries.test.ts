import bcrypt from 'bcryptjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import request from 'supertest';

const mocks = vi.hoisted(() => ({
  findUser: vi.fn(),
  findSession: vi.fn(),
  createSession: vi.fn(),
  transaction: vi.fn(),
}));

vi.mock('./db.js', () => ({
  db: {
    user: { findUnique: mocks.findUser },
    refreshSession: {
      findUnique: mocks.findSession,
      create: mocks.createSession,
    },
    $transaction: mocks.transaction,
  },
}));

import { app } from './app.js';
import { signRefresh } from './security.js';

const credentials = {
  email: 'blocked@example.com',
  password: 'StrongPass1!',
};

describe('authentication account boundaries', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('does not issue a session to a suspended account', async () => {
    mocks.findUser.mockResolvedValue({
      id: 'user-1',
      email: credentials.email,
      name: 'Blocked User',
      passwordHash: await bcrypt.hash(credentials.password, 4),
      status: 'SUSPENDED',
      deletedAt: null,
      memberships: [],
    });

    const response = await request(app)
      .post('/api/v1/auth/login')
      .send(credentials);

    expect(response.status).toBe(403);
    expect(response.body.error.code).toBe('ACCOUNT_INACTIVE');
    expect(mocks.createSession).not.toHaveBeenCalled();
  });

  it('does not issue a session when the selected membership is inactive', async () => {
    const businessId = '3d5931fb-3ce2-4604-be57-b39372aba5b4';
    mocks.findUser.mockResolvedValue({
      id: 'user-1',
      email: credentials.email,
      name: 'Former Member',
      passwordHash: await bcrypt.hash(credentials.password, 4),
      status: 'ACTIVE',
      deletedAt: null,
      memberships: [
        {
          active: false,
          businessId,
          role: { name: 'ADMIN', permissions: [] },
          business: { id: businessId },
        },
      ],
    });

    const response = await request(app)
      .post('/api/v1/auth/login')
      .send({ ...credentials, businessId });

    expect(response.status).toBe(403);
    expect(response.body.error.code).toBe('TENANT_FORBIDDEN');
    expect(mocks.createSession).not.toHaveBeenCalled();
  });

  it('does not rotate a refresh token for an inactive account', async () => {
    const businessId = '3d5931fb-3ce2-4604-be57-b39372aba5b4';
    const refreshToken = signRefresh('user-1', businessId);
    mocks.findSession.mockResolvedValue({
      id: 'session-1',
      userId: 'user-1',
      revokedAt: null,
      expiresAt: new Date(Date.now() + 60_000),
      user: {
        id: 'user-1',
        status: 'SUSPENDED',
        deletedAt: null,
        memberships: [],
      },
    });

    const response = await request(app)
      .post('/api/v1/auth/refresh-token')
      .send({ refreshToken });

    expect(response.status).toBe(403);
    expect(response.body.error.code).toBe('ACCOUNT_INACTIVE');
    expect(mocks.transaction).not.toHaveBeenCalled();
  });
});
