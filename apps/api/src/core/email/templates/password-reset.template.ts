import type { EmailContent } from './verification.template.js';

export const passwordResetTemplate = ({ code }: { code: string }): EmailContent => ({
  subject: 'Reset your Tribely password',
  text: [
    'We received a request to reset your Tribely password.',
    '',
    `Your reset code is: ${code}`,
    '',
    'Enter this code in the app to set a new password.',
    '',
    "If you didn't request a reset, you can safely ignore this email — your password won't change.",
  ].join('\n'),
  html: `<!doctype html>
<html lang="en">
  <body style="margin:0;padding:24px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;color:#0f172a;background:#f8fafc;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:480px;margin:0 auto;background:#ffffff;border-radius:12px;padding:32px;">
      <tr><td>
        <h1 style="margin:0 0 16px;font-size:20px;font-weight:600;">Reset your password</h1>
        <p style="margin:0 0 24px;line-height:1.5;">Enter this code in the app to set a new password:</p>
        <p style="margin:0 0 24px;text-align:center;">
          <span style="display:inline-block;padding:16px 24px;border-radius:8px;background:#0f172a;color:#ffffff;font-size:28px;font-weight:700;letter-spacing:8px;font-family:ui-monospace,SFMono-Regular,Menlo,monospace;">${code}</span>
        </p>
        <p style="margin:0;color:#64748b;font-size:13px;">If you didn't request a reset, you can safely ignore this email — your password won't change.</p>
      </td></tr>
    </table>
  </body>
</html>`,
});
