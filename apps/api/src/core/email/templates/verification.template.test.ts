import { describe, expect, it } from 'vitest';
import { verificationTemplate } from './verification.template.js';

describe('verificationTemplate', () => {
  const verifyUrl = 'https://example.tribely.app/auth/verify?token=abc123';

  it('returns a stable subject', () => {
    expect(verificationTemplate({ verifyUrl }).subject).toBe('Verify your Tribely email');
  });

  it('embeds the verify URL in the plain-text body', () => {
    expect(verificationTemplate({ verifyUrl }).text).toContain(verifyUrl);
  });

  it('embeds the verify URL twice in HTML (button + paste-link)', () => {
    const html = verificationTemplate({ verifyUrl }).html;
    const matches = html.match(new RegExp(verifyUrl.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g'));
    expect(matches?.length ?? 0).toBeGreaterThanOrEqual(2);
  });

  it('mentions Tribely by name so recipients recognize the sender', () => {
    const { html, text } = verificationTemplate({ verifyUrl });
    expect(text).toMatch(/Tribely/);
    expect(html).toMatch(/Tribely/);
  });
});
