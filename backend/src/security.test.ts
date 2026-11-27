import { describe, expect, it } from 'vitest';
import { signRefresh, verifyRefresh } from './security.js';

describe('refresh token tenant binding', () => {
  it('keeps the selected business in a rotated session token', () => {
    const token = signRefresh('user-1', 'business-2');
    const payload = verifyRefresh(token);

    expect(payload.sub).toBe('user-1');
    expect(payload.businessId).toBe('business-2');
  });
});
