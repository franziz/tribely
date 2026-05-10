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

  it('sendVerification resolves and logs to/code', async () => {
    const sender = new LoggingEmailSender();
    await expect(
      sender.sendVerification({ to: 'user@example.com', code: '123456' }),
    ).resolves.toBeUndefined();

    expect(infoSpy).toHaveBeenCalledTimes(1);
    expect(infoSpy).toHaveBeenCalledWith(
      { to: 'user@example.com', code: '123456' },
      expect.stringContaining('email.sendVerification'),
    );
  });

  it('sendPasswordReset resolves and logs to/code', async () => {
    const sender = new LoggingEmailSender();
    await expect(
      sender.sendPasswordReset({ to: 'user@example.com', code: '654321' }),
    ).resolves.toBeUndefined();

    expect(infoSpy).toHaveBeenCalledTimes(1);
    expect(infoSpy).toHaveBeenCalledWith(
      { to: 'user@example.com', code: '654321' },
      expect.stringContaining('email.sendPasswordReset'),
    );
  });
});
