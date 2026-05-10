export interface EmailContent {
  subject: string;
  html: string;
  text: string;
}

export const verificationTemplate = ({ code }: { code: string }): EmailContent => ({
  subject: 'Your Tribely verification code',
  text: [
    'Welcome to Tribely.',
    '',
    `Your verification code is: ${code}`,
    '',
    'Enter this code in the app to verify your email. The code expires in 48 hours.',
    '',
    "If you didn't sign up for Tribely, you can ignore this message.",
  ].join('\n'),
  html: `<!doctype html>
<html lang="en">
  <body style="margin:0;padding:24px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;color:#0f172a;background:#f8fafc;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:480px;margin:0 auto;background:#ffffff;border-radius:12px;padding:32px;">
      <tr><td>
        <h1 style="margin:0 0 16px;font-size:20px;font-weight:600;">Welcome to Tribely</h1>
        <p style="margin:0 0 24px;line-height:1.5;">Enter this code in the app to verify your email:</p>
        <p style="margin:0 0 24px;text-align:center;">
          <span style="display:inline-block;padding:16px 24px;border-radius:8px;background:#0f172a;color:#ffffff;font-size:28px;font-weight:700;letter-spacing:8px;font-family:ui-monospace,SFMono-Regular,Menlo,monospace;">${code}</span>
        </p>
        <p style="margin:0 0 8px;color:#64748b;font-size:13px;">This code expires in 48 hours.</p>
        <p style="margin:0;color:#64748b;font-size:13px;">If you didn't sign up for Tribely, you can ignore this message.</p>
      </td></tr>
    </table>
  </body>
</html>`,
});
