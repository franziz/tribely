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

  it('send resolves and logs to/subject', async () => {
    const sender = new LoggingEmailSender();
    await expect(
      sender.send({
        to: 'user@example.com',
        subject: 'Your Tribely verification code',
        html: '<p>code: 123456</p>',
        text: 'code: 123456',
      }),
    ).resolves.toBeUndefined();

    expect(infoSpy).toHaveBeenCalledTimes(1);
    expect(infoSpy).toHaveBeenCalledWith(
      { to: 'user@example.com', subject: 'Your Tribely verification code' },
      expect.stringContaining('email.send'),
    );
  });

  it('send resolves for any email type (password reset)', async () => {
    const sender = new LoggingEmailSender();
    await expect(
      sender.send({
        to: 'user@example.com',
        subject: 'Reset your Tribely password',
        html: '<p>code: 654321</p>',
        text: 'code: 654321',
      }),
    ).resolves.toBeUndefined();

    expect(infoSpy).toHaveBeenCalledTimes(1);
    expect(infoSpy).toHaveBeenCalledWith(
      { to: 'user@example.com', subject: 'Reset your Tribely password' },
      expect.stringContaining('email.send'),
    );
  });
});
