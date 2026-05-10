import { describe, expect, it } from 'vitest';
import { verificationTemplate } from './verification.template.js';

describe('verificationTemplate', () => {
  const code = '482917';

  it('returns a stable subject', () => {
    expect(verificationTemplate({ code }).subject).toBe('Your Tribely verification code');
  });

  it('embeds the code in the plain-text body', () => {
    expect(verificationTemplate({ code }).text).toContain(code);
  });

  it('embeds the code in the HTML body', () => {
    expect(verificationTemplate({ code }).html).toContain(code);
  });

  it('mentions Tribely by name so recipients recognize the sender', () => {
    const { html, text } = verificationTemplate({ code });
    expect(text).toMatch(/Tribely/);
    expect(html).toMatch(/Tribely/);
  });
});
