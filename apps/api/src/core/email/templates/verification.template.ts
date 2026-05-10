export interface EmailContent {
  subject: string;
  html: string;
  text: string;
}

export const verificationTemplate = ({ verifyUrl }: { verifyUrl: string }): EmailContent => ({
  subject: 'Verify your Tribely email',
  text: [
    'Welcome to Tribely.',
    '',
    'Confirm your email address to start joining and creating events:',
    verifyUrl,
    '',
    "If you didn't sign up for Tribely, you can ignore this message.",
  ].join('\n'),
  html: `<!doctype html>
<html lang="en">
  <body style="margin:0;padding:24px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;color:#0f172a;background:#f8fafc;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:480px;margin:0 auto;background:#ffffff;border-radius:12px;padding:32px;">
      <tr><td>
        <h1 style="margin:0 0 16px;font-size:20px;font-weight:600;">Welcome to Tribely</h1>
        <p style="margin:0 0 24px;line-height:1.5;">Confirm your email address to start joining and creating events.</p>
        <p style="margin:0 0 24px;">
          <a href="${verifyUrl}" style="display:inline-block;padding:12px 20px;border-radius:8px;background:#0f172a;color:#ffffff;text-decoration:none;font-weight:600;">Verify email</a>
        </p>
        <p style="margin:0 0 8px;color:#64748b;font-size:13px;">Or paste this link into your browser:</p>
        <p style="margin:0 0 24px;word-break:break-all;font-size:13px;"><a href="${verifyUrl}" style="color:#0f172a;">${verifyUrl}</a></p>
        <p style="margin:0;color:#64748b;font-size:13px;">If you didn't sign up for Tribely, you can ignore this message.</p>
      </td></tr>
    </table>
  </body>
</html>`,
});
