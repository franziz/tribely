import { describe, expect, it } from 'vitest';
import { CREDENTIAL_ISSUED } from '../events/credential-issued.event.js';
import { PASSWORD_RESET } from '../events/password-reset.event.js';
import { HashedPassword } from '../value-objects/hashed-password.js';
import { Credential } from './credential.js';

const issued = (now = new Date('2026-01-01T00:00:00Z')): Credential =>
  Credential.issue({
    userId: 'user_1',
    passwordHash: HashedPassword.fromHash('hash:original'),
    now,
  });

describe('Credential', () => {
  describe('issue', () => {
    it('records credentialIssued event', () => {
      const c = issued();
      const events = c.pullEvents();
      expect(events).toHaveLength(1);
      expect(events[0]?.type).toBe(CREDENTIAL_ISSUED);
    });

    it('initializes passwordSetAt to issuance time', () => {
      const at = new Date('2026-01-01T00:00:00Z');
      const c = issued(at);
      expect(c.passwordSetAt).toEqual(at);
    });
  });

  describe('changePassword', () => {
    it('replaces the hash and bumps passwordSetAt', () => {
      const c = issued();
      c.pullEvents();
      const newHash = HashedPassword.fromHash('hash:new');
      const at = new Date('2026-02-01T00:00:00Z');

      c.changePassword(newHash, at);

      expect(c.passwordHash).toBe(newHash);
      expect(c.passwordSetAt).toEqual(at);
    });

    it('records auth.passwordReset event', () => {
      const c = issued();
      c.pullEvents();
      const at = new Date('2026-02-01T00:00:00Z');

      c.changePassword(HashedPassword.fromHash('hash:new'), at);

      const events = c.pullEvents();
      expect(events).toHaveLength(1);
      expect(events[0]?.type).toBe(PASSWORD_RESET);
      expect(events[0]?.payload).toMatchObject({ userId: 'user_1', resetAt: at.toISOString() });
    });
  });
});
