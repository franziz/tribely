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

  it('forwards to/subject/html/text to the Resend SDK', async () => {
    sendMock.mockResolvedValueOnce({ data: { id: 'em_1' }, error: null });
    const sender = new ResendEmailSender('re_test_key', 'Tribely <noreply@tribely.app>');

    await sender.send({
      to: 'user@example.com',
      subject: 'Test subject',
      html: '<p>Hello</p>',
      text: 'Hello',
    });

    expect(sendMock).toHaveBeenCalledTimes(1);
    const payload = sendMock.mock.calls[0]?.[0];
    expect(payload).toMatchObject({
      from: 'Tribely <noreply@tribely.app>',
      to: 'user@example.com',
      subject: 'Test subject',
      html: '<p>Hello</p>',
      text: 'Hello',
    });
  });

  it('throws when Resend returns an error', async () => {
    sendMock.mockResolvedValueOnce({
      data: null,
      error: { name: 'validation_error', message: 'Invalid `to` address', statusCode: 422 },
    });
    const sender = new ResendEmailSender('re_test_key', 'Tribely <noreply@tribely.app>');

    await expect(
      sender.send({
        to: 'bogus',
        subject: 'Test subject',
        html: '<p>Hello</p>',
        text: 'Hello',
      }),
    ).rejects.toThrow(/Resend send failed: validation_error: Invalid `to` address/);
  });

  it('throws with correct error details on rate limit', async () => {
    sendMock.mockResolvedValueOnce({
      data: null,
      error: { name: 'rate_limit_exceeded', message: 'Too many requests', statusCode: 429 },
    });
    const sender = new ResendEmailSender('re_test_key', 'Tribely <noreply@tribely.app>');

    await expect(
      sender.send({
        to: 'user@example.com',
        subject: 'Test subject',
        html: '<p>Hello</p>',
        text: 'Hello',
      }),
    ).rejects.toThrow(/Resend send failed: rate_limit_exceeded: Too many requests/);
  });
});
