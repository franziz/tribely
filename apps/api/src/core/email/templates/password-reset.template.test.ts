import { describe, expect, it } from 'vitest';
import { passwordResetTemplate } from './password-reset.template.js';

describe('passwordResetTemplate', () => {
  const code = '739104';

  it('returns a stable subject', () => {
    expect(passwordResetTemplate({ code }).subject).toBe('Reset your Tribely password');
  });

  it('embeds the code in the plain-text body', () => {
    expect(passwordResetTemplate({ code }).text).toContain(code);
  });

  it('embeds the code in the HTML body', () => {
    expect(passwordResetTemplate({ code }).html).toContain(code);
  });

  it('reassures recipients who did not request a reset', () => {
    const { html, text } = passwordResetTemplate({ code });
    expect(text).toMatch(/didn't request/);
    expect(html).toMatch(/didn't request/);
  });
});
