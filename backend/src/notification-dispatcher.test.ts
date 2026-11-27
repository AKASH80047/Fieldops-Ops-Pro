import { beforeEach, describe, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => ({
  firebaseMessaging: vi.fn(),
  findDevices: vi.fn(),
  disableDevices: vi.fn(),
  findNotification: vi.fn(),
  sendEachForMulticast: vi.fn(),
}));

vi.mock('./firebase-admin.js', () => ({ firebaseMessaging: mocks.firebaseMessaging }));
vi.mock('./db.js', () => ({
  db: {
    deviceToken: {
      findMany: mocks.findDevices,
      updateMany: mocks.disableDevices,
    },
    notification: { findUnique: mocks.findNotification },
  },
}));

import { dispatchPushToUsers, dispatchStoredNotification } from './notification-dispatcher.js';

describe('Firebase notification dispatcher', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.firebaseMessaging.mockReturnValue({
      sendEachForMulticast: mocks.sendEachForMulticast,
    });
    mocks.disableDevices.mockResolvedValue({ count: 1 });
  });

  it('skips safely when Firebase credentials are not configured', async () => {
    mocks.firebaseMessaging.mockReturnValue(null);

    const result = await dispatchPushToUsers(['user-1'], {
      title: 'New job',
      body: 'A nearby job is available.',
    });

    expect(result.configured).toBe(false);
    expect(result.targeted).toBe(0);
    expect(mocks.findDevices).not.toHaveBeenCalled();
  });

  it('sends to enabled devices and disables rejected registration tokens', async () => {
    mocks.findDevices.mockResolvedValue([
      { token: 'valid-token' },
      { token: 'expired-token' },
    ]);
    mocks.sendEachForMulticast.mockResolvedValue({
      successCount: 1,
      failureCount: 1,
      responses: [
        { success: true, messageId: 'message-1' },
        {
          success: false,
          error: { code: 'messaging/registration-token-not-registered' },
        },
      ],
    });

    const result = await dispatchPushToUsers(['user-1'], {
      title: 'New job',
      body: 'A nearby job is available.',
      type: 'JOB_AVAILABLE',
      data: { jobId: 'job-1' },
    });

    expect(result).toEqual({
      configured: true,
      targeted: 2,
      sent: 1,
      failed: 1,
      invalidTokensDisabled: 1,
    });
    expect(mocks.disableDevices).toHaveBeenCalledWith({
      where: { token: { in: ['expired-token'] }, enabled: true },
      data: { enabled: false },
    });
  });

  it('loads and delivers a committed notification without throwing on send failure', async () => {
    mocks.findNotification.mockResolvedValue({
      id: 'notification-1',
      userId: 'user-1',
      title: 'Job assigned',
      body: 'A job was assigned to you.',
      type: 'JOB_ASSIGNED',
    });
    mocks.findDevices.mockResolvedValue([{ token: 'device-token' }]);
    mocks.sendEachForMulticast.mockRejectedValue(new Error('FCM unavailable'));

    const result = await dispatchStoredNotification('notification-1');

    expect(result.configured).toBe(true);
    expect(result.targeted).toBe(1);
    expect(result.failed).toBe(1);
  });
});

