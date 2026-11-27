import type { BatchResponse, Messaging, MulticastMessage } from 'firebase-admin/messaging';
import { db } from './db.js';
import { firebaseMessaging } from './firebase-admin.js';

const multicastLimit = 500;
const invalidTokenCodes = new Set([
  'messaging/invalid-registration-token',
  'messaging/registration-token-not-registered',
]);

export type PushPayload = {
  title: string;
  body: string;
  type?: string;
  notificationId?: string;
  data?: Record<string, string | number | boolean | null | undefined>;
};

export type PushDispatchResult = {
  configured: boolean;
  targeted: number;
  sent: number;
  failed: number;
  invalidTokensDisabled: number;
};

const emptyResult = (configured: boolean): PushDispatchResult => ({
  configured,
  targeted: 0,
  sent: 0,
  failed: 0,
  invalidTokensDisabled: 0,
});

function stringData(payload: PushPayload): Record<string, string> {
  const values: Record<string, string | number | boolean | null | undefined> = {
    ...(payload.data ?? {}),
    type: payload.type,
    notificationId: payload.notificationId,
  };
  return Object.fromEntries(
    Object.entries(values)
      .filter(([, value]) => value !== null && value !== undefined)
      .map(([key, value]) => [key, String(value)]),
  );
}

function message(tokens: string[], payload: PushPayload): MulticastMessage {
  return {
    tokens,
    notification: { title: payload.title, body: payload.body },
    data: stringData(payload),
    android: { priority: 'high' },
    apns: { payload: { aps: { sound: 'default' } } },
  };
}

function invalidTokens(tokens: string[], response: BatchResponse): string[] {
  return response.responses.flatMap((item, index) => {
    const code = item.error?.code;
    return code && invalidTokenCodes.has(code) ? [tokens[index]] : [];
  });
}

async function disableInvalidTokens(tokens: string[]): Promise<number> {
  if (tokens.length === 0) return 0;
  try {
    const result = await db.deviceToken.updateMany({
      where: { token: { in: [...new Set(tokens)] }, enabled: true },
      data: { enabled: false },
    });
    return result.count;
  } catch (error) {
    console.warn('[push] Invalid device tokens could not be disabled', error);
    return 0;
  }
}

async function send(
  client: Messaging,
  tokens: string[],
  payload: PushPayload,
): Promise<PushDispatchResult> {
  const result = emptyResult(true);
  result.targeted = tokens.length;
  const invalid: string[] = [];

  for (let start = 0; start < tokens.length; start += multicastLimit) {
    const chunk = tokens.slice(start, start + multicastLimit);
    try {
      const response = await client.sendEachForMulticast(message(chunk, payload));
      result.sent += response.successCount;
      result.failed += response.failureCount;
      invalid.push(...invalidTokens(chunk, response));
    } catch (error) {
      result.failed += chunk.length;
      console.warn('[push] Firebase rejected a multicast batch', error);
    }
  }

  result.invalidTokensDisabled = await disableInvalidTokens(invalid);
  return result;
}

/**
 * Best-effort push delivery to all enabled devices belonging to the supplied
 * users. This method never throws: the database notification remains the
 * durable source of truth when Firebase is absent or unavailable.
 *
 * Call this only after the transaction that creates the notification commits.
 */
export async function dispatchPushToUsers(
  userIds: string[],
  payload: PushPayload,
): Promise<PushDispatchResult> {
  const client = firebaseMessaging();
  if (!client) return emptyResult(false);

  const uniqueUserIds = [...new Set(userIds.filter(Boolean))];
  if (uniqueUserIds.length === 0) return emptyResult(true);

  try {
    const devices = await db.deviceToken.findMany({
      where: { userId: { in: uniqueUserIds }, enabled: true },
      select: { token: true },
    });
    const tokens = [...new Set(devices.map((device) => device.token).filter(Boolean))];
    if (tokens.length === 0) return emptyResult(true);
    return await send(client, tokens, payload);
  } catch (error) {
    console.warn('[push] Device lookup or delivery failed', error);
    return emptyResult(true);
  }
}

/** Delivers a previously committed Notification row to its owning user. */
export async function dispatchStoredNotification(notificationId: string): Promise<PushDispatchResult> {
  try {
    const notification = await db.notification.findUnique({ where: { id: notificationId } });
    if (!notification) return emptyResult(firebaseMessaging() !== null);
    return await dispatchPushToUsers([notification.userId], {
      title: notification.title,
      body: notification.body,
      type: notification.type,
      notificationId: notification.id,
    });
  } catch (error) {
    console.warn('[push] Stored notification could not be dispatched', error);
    return emptyResult(firebaseMessaging() !== null);
  }
}

