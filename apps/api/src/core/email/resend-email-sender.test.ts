import { beforeEach, describe, expect, it, vi } from 'vitest';

const sendMock = vi.fn();

vi.mock('resend', () => ({
  Resend: vi.fn().mockImplementation(() => ({
    emails: { send: sendMock },
  })),
}));

// Import AFTER vi.mock so the adapter picks up the mocked SDK.
const { ResendEmailSender } = await import('./resend-email-sender.js');

describe('ResendEmailSender', () => {
  beforeEach(() => {
    sendMock.mockReset();
  });

  describe('sendVerification', () => {
    it('forwards to/subject/html/text to the Resend SDK', async () => {
      sendMock.mockResolvedValueOnce({ data: { id: 'em_1' }, error: null });
      const sender = new ResendEmailSender('re_test_key', 'Tribely <noreply@tribely.app>');

      await sender.sendVerification({ to: 'user@example.com', code: '123456' });

      expect(sendMock).toHaveBeenCalledTimes(1);
      const payload = sendMock.mock.calls[0]?.[0];
      expect(payload).toMatchObject({
        from: 'Tribely <noreply@tribely.app>',
        to: 'user@example.com',
        subject: 'Your Tribely verification code',
      });
      expect(payload.html).toContain('123456');
      expect(payload.text).toContain('123456');
    });

    it('throws when Resend returns an error', async () => {
      sendMock.mockResolvedValueOnce({
        data: null,
        error: { name: 'validation_error', message: 'Invalid `to` address', statusCode: 422 },
      });
      const sender = new ResendEmailSender('re_test_key', 'Tribely <noreply@tribely.app>');

      await expect(
        sender.sendVerification({ to: 'bogus', code: '123456' }),
      ).rejects.toThrow(/Resend send failed: validation_error: Invalid `to` address/);
    });
  });

  describe('sendPasswordReset', () => {
    it('forwards to/subject/html/text to the Resend SDK', async () => {
      sendMock.mockResolvedValueOnce({ data: { id: 'em_2' }, error: null });
      const sender = new ResendEmailSender('re_test_key', 'Tribely <noreply@tribely.app>');

      await sender.sendPasswordReset({ to: 'user@example.com', code: '654321' });

      expect(sendMock).toHaveBeenCalledTimes(1);
      const payload = sendMock.mock.calls[0]?.[0];
      expect(payload).toMatchObject({
        from: 'Tribely <noreply@tribely.app>',
        to: 'user@example.com',
        subject: 'Reset your Tribely password',
      });
      expect(payload.html).toContain('654321');
      expect(payload.text).toContain('654321');
    });

    it('throws when Resend returns an error', async () => {
      sendMock.mockResolvedValueOnce({
        data: null,
        error: { name: 'rate_limit_exceeded', message: 'Too many requests', statusCode: 429 },
      });
      const sender = new ResendEmailSender('re_test_key', 'Tribely <noreply@tribely.app>');

      await expect(
        sender.sendPasswordReset({ to: 'user@example.com', code: '654321' }),
      ).rejects.toThrow(/Resend send failed: rate_limit_exceeded: Too many requests/);
    });
  });
});
