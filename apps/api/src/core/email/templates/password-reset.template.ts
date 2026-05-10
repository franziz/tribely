import type { EmailContent } from './verification.template.js';

export const passwordResetTemplate = ({ resetUrl }: { resetUrl: string }): EmailContent => ({
  subject: 'Reset your Tribely password',
  text: [
    'We received a request to reset your Tribely password.',
    '',
    'Use this link to set a new one (valid for a limited time):',
    resetUrl,
    '',
    "If you didn't request a reset, you can safely ignore this email — your password won't change.",
  ].join('\n'),
  html: `<!doctype html>
<html lang="en">
  <body style="margin:0;padding:24px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;color:#0f172a;background:#f8fafc;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:480px;margin:0 auto;background:#ffffff;border-radius:12px;padding:32px;">
      <tr><td>
        <h1 style="margin:0 0 16px;font-size:20px;font-weight:600;">Reset your password</h1>
        <p style="margin:0 0 24px;line-height:1.5;">We received a request to reset your Tribely password. Use the button below to set a new one.</p>
        <p style="margin:0 0 24px;">
          <a href="${resetUrl}" style="display:inline-block;padding:12px 20px;border-radius:8px;background:#0f172a;color:#ffffff;text-decoration:none;font-weight:600;">Reset password</a>
        </p>
        <p style="margin:0 0 8px;color:#64748b;font-size:13px;">Or paste this link into your browser:</p>
        <p style="margin:0 0 24px;word-break:break-all;font-size:13px;"><a href="${resetUrl}" style="color:#0f172a;">${resetUrl}</a></p>
        <p style="margin:0;color:#64748b;font-size:13px;">If you didn't request a reset, you can safely ignore this email — your password won't change.</p>
      </td></tr>
    </table>
  </body>
</html>`,
});
