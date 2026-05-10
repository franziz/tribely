import { describe, expect, it } from 'vitest';
import { passwordResetTemplate } from './password-reset.template.js';

describe('passwordResetTemplate', () => {
  const resetUrl = 'https://example.tribely.app/auth/reset?token=xyz789';

  it('returns a stable subject', () => {
    expect(passwordResetTemplate({ resetUrl }).subject).toBe('Reset your Tribely password');
  });

  it('embeds the reset URL in the plain-text body', () => {
    expect(passwordResetTemplate({ resetUrl }).text).toContain(resetUrl);
  });

  it('embeds the reset URL twice in HTML (button + paste-link)', () => {
    const html = passwordResetTemplate({ resetUrl }).html;
    const matches = html.match(new RegExp(resetUrl.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g'));
    expect(matches?.length ?? 0).toBeGreaterThanOrEqual(2);
  });

  it('reassures recipients who did not request a reset', () => {
    const { html, text } = passwordResetTemplate({ resetUrl });
    expect(text).toMatch(/didn't request/);
    expect(html).toMatch(/didn't request/);
  });
});
