import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { logger } from '../middleware/logger.js';
import { LoggingEmailSender } from './logging-email-sender.js';

describe('LoggingEmailSender', () => {
  let infoSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    infoSpy = vi.spyOn(logger, 'info').mockImplementation(() => undefined);
  });

  afterEach(() => {
    infoSpy.mockRestore();
  });

  it('sendVerification resolves and logs to/verifyUrl', async () => {
    const sender = new LoggingEmailSender();
    await expect(
      sender.sendVerification({ to: 'user@example.com', verifyUrl: 'https://x/verify?t=1' }),
    ).resolves.toBeUndefined();

    expect(infoSpy).toHaveBeenCalledTimes(1);
    expect(infoSpy).toHaveBeenCalledWith(
      { to: 'user@example.com', verifyUrl: 'https://x/verify?t=1' },
      expect.stringContaining('email.sendVerification'),
    );
  });

  it('sendPasswordReset resolves and logs to/resetUrl', async () => {
    const sender = new LoggingEmailSender();
    await expect(
      sender.sendPasswordReset({ to: 'user@example.com', resetUrl: 'https://x/reset?t=2' }),
    ).resolves.toBeUndefined();

    expect(infoSpy).toHaveBeenCalledTimes(1);
    expect(infoSpy).toHaveBeenCalledWith(
      { to: 'user@example.com', resetUrl: 'https://x/reset?t=2' },
      expect.stringContaining('email.sendPasswordReset'),
    );
  });
});
