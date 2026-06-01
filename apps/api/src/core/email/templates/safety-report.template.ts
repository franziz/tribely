import type { EmailContent } from './verification.template.js';

export interface SafetyReportTemplateInput {
  checkInId: string;
  userId: string;
  eventId: string;
  eventTitle: string;
  hostUserId: string;
  flaggedAt: string;
  reportBody: string;
  /** Whether the reporting user acknowledged the safety disclaimer before submitting. */
  disclaimerAcknowledged: boolean;
}

/**
 * Safety-report email sent to `safety@gotribely.com` when a check-in is
 * flagged. Body intentionally uses IDs + free-text only — no display names,
 * no avatar URLs, no phone numbers, no emails. The destination mailbox is
 * external (PDPA s26 / out-of-region); PII stays in the SG-region DB.
 *
 * Subject is single-line, scannable, no PII.
 *
 * @param disclaimerAcknowledged - Whether the reporting user acknowledged the
 *   safety disclaimer before submitting. Operator-visible; rendered as YES/NO.
 */
export const safetyReportTemplate = ({
  checkInId,
  userId,
  eventId,
  eventTitle,
  hostUserId,
  flaggedAt,
  reportBody,
  disclaimerAcknowledged,
}: SafetyReportTemplateInput): EmailContent => {
  const subject = `[Tribely safety] event=${eventId} attendee=${userId}`;

  // Escape HTML special characters in user-supplied strings to prevent
  // any injection from reportBody or the truncated title.
  const escapeHtml = (raw: string): string =>
    raw
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');

  const text = [
    'A user has reported a safety concern after attending an event on Tribely.',
    '',
    `Check-in ID: ${checkInId}`,
    `Event ID:    ${eventId}`,
    `Event title: ${eventTitle}`,
    `Host user ID:     ${hostUserId}`,
    `Attendee user ID: ${userId}`,
    `Flagged at:  ${flaggedAt}`,
    `Disclaimer acknowledged: ${disclaimerAcknowledged ? 'YES' : 'NO'}`,
    '',
    'Report:',
    reportBody,
    '',
    '---',
    'Respond within SG business hours (Mon–Fri 9am–9pm SGT, excluding public holidays). SOP: TRI-127 (ops staffing rotation). 999 Singapore Police if immediate danger to anyone involved.',
  ].join('\n');

  const html = `<!doctype html>
<html lang="en">
  <body style="margin:0;padding:24px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;color:#0f172a;background:#f8fafc;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:600px;margin:0 auto;background:#ffffff;border-radius:12px;padding:32px;">
      <tr><td>
        <h1 style="margin:0 0 8px;font-size:20px;font-weight:600;color:#dc2626;">[Tribely safety] Safety concern reported</h1>
        <p style="margin:0 0 24px;line-height:1.5;color:#374151;">A user has reported a safety concern after attending an event on Tribely.</p>

        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border:1px solid #e5e7eb;border-radius:8px;margin:0 0 24px;">
          <tr>
            <td style="padding:12px 16px;border-bottom:1px solid #e5e7eb;font-size:13px;">
              <span style="color:#6b7280;font-weight:500;">Check-in ID</span><br>
              <code style="font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:13px;color:#0f172a;">${escapeHtml(checkInId)}</code>
            </td>
          </tr>
          <tr>
            <td style="padding:12px 16px;border-bottom:1px solid #e5e7eb;font-size:13px;">
              <span style="color:#6b7280;font-weight:500;">Event ID</span><br>
              <code style="font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:13px;color:#0f172a;">${escapeHtml(eventId)}</code>
            </td>
          </tr>
          <tr>
            <td style="padding:12px 16px;border-bottom:1px solid #e5e7eb;font-size:13px;">
              <span style="color:#6b7280;font-weight:500;">Event title</span><br>
              <span style="color:#0f172a;">${escapeHtml(eventTitle)}</span>
            </td>
          </tr>
          <tr>
            <td style="padding:12px 16px;border-bottom:1px solid #e5e7eb;font-size:13px;">
              <span style="color:#6b7280;font-weight:500;">Host user ID</span><br>
              <code style="font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:13px;color:#0f172a;">${escapeHtml(hostUserId)}</code>
            </td>
          </tr>
          <tr>
            <td style="padding:12px 16px;border-bottom:1px solid #e5e7eb;font-size:13px;">
              <span style="color:#6b7280;font-weight:500;">Attendee user ID</span><br>
              <code style="font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:13px;color:#0f172a;">${escapeHtml(userId)}</code>
            </td>
          </tr>
          <tr>
            <td style="padding:12px 16px;border-bottom:1px solid #e5e7eb;font-size:13px;">
              <span style="color:#6b7280;font-weight:500;">Flagged at</span><br>
              <span style="color:#0f172a;">${escapeHtml(flaggedAt)}</span>
            </td>
          </tr>
          <tr>
            <td style="padding:12px 16px;font-size:13px;">
              <span style="color:#6b7280;font-weight:500;">Disclaimer acknowledged</span><br>
              <code style="font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:13px;color:#0f172a;">${disclaimerAcknowledged ? 'YES' : 'NO'}</code>
            </td>
          </tr>
        </table>

        <h2 style="margin:0 0 8px;font-size:15px;font-weight:600;">Report:</h2>
        <pre style="margin:0 0 24px;padding:16px;background:#f9fafb;border:1px solid #e5e7eb;border-radius:8px;font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:13px;white-space:pre-wrap;word-break:break-word;color:#0f172a;">${escapeHtml(reportBody)}</pre>

        <hr style="border:none;border-top:1px solid #e5e7eb;margin:0 0 16px;">
        <p style="margin:0;color:#6b7280;font-size:12px;line-height:1.6;">
          Respond within SG business hours (Mon–Fri 9am–9pm SGT, excluding public holidays). SOP: TRI-127 (ops staffing rotation).
          999 Singapore Police if immediate danger to anyone involved.
        </p>
      </td></tr>
    </table>
  </body>
</html>`;

  return { subject, text, html };
};
