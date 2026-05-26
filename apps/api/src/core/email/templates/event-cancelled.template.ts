import type { EmailContent } from './verification.template.js';

export interface EventCancelledTemplateInput {
  eventTitle: string;
  eventStartsAt: Date;
}

/**
 * Formats `startsAt` in Singapore-launch English:
 * "Mon, 12 Jun 2026 — 7:30 PM SGT"
 *
 * Uses the Asia/Singapore locale so the output is always in SGT regardless of
 * the server's TZ env (which must NOT be relied upon in a hosted environment).
 */
const formatStartsAt = (startsAt: Date): string => {
  const datePart = startsAt.toLocaleDateString('en-SG', {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    timeZone: 'Asia/Singapore',
  });

  const timePart = startsAt.toLocaleTimeString('en-SG', {
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
    timeZone: 'Asia/Singapore',
  });

  // toLocaleTimeString on en-SG produces e.g. "7:30 pm" — uppercase for display.
  const timeFormatted = timePart.replace(/am|pm/i, (m) => m.toUpperCase());

  return `${datePart} — ${timeFormatted} SGT`;
};

/**
 * Notification email sent to the host + all active joiners (approved and
 * pending) when ANY event is cancelled — whether by the host or a moderator.
 *
 * Legal invariants (Option A, locked by PM for TRI-193 AC #5):
 *   - Must NOT name the reporter, the reported user, or imply moderation.
 *   - Must NOT include the cancellation reason from the domain event payload.
 *   - Must NOT include any operator justification text.
 *   - Same copy for ALL cancellation origins (host-initiated vs. moderator).
 *
 * The template receives only `eventTitle` + `eventStartsAt` — fields that
 * carry zero inference risk about the cancellation trigger.
 */
export const eventCancelledEmail = ({
  eventTitle,
  eventStartsAt,
}: EventCancelledTemplateInput): EmailContent => {
  const eventStartsAtFormatted = formatStartsAt(eventStartsAt);

  // Escape HTML to prevent any injection via event titles created by hosts.
  const escapeHtml = (raw: string): string =>
    raw
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');

  const subject = `Event cancelled: ${eventTitle}`;

  const text = [
    'Hi,',
    '',
    "This event has been cancelled. We're sorry for the inconvenience.",
    '',
    `Event: ${eventTitle}`,
    `Originally scheduled: ${eventStartsAtFormatted}`,
    '',
    '— The Tribely team',
  ].join('\n');

  const html = `<!doctype html>
<html lang="en">
  <body style="margin:0;padding:24px;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;color:#0f172a;background:#f8fafc;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:600px;margin:0 auto;background:#ffffff;border-radius:12px;padding:32px;">
      <tr><td>
        <h1 style="margin:0 0 16px;font-size:20px;font-weight:600;color:#0f172a;">Event cancelled</h1>
        <p style="margin:0 0 24px;line-height:1.5;color:#374151;">This event has been cancelled. We&#39;re sorry for the inconvenience.</p>

        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="border:1px solid #e5e7eb;border-radius:8px;margin:0 0 24px;">
          <tr>
            <td style="padding:12px 16px;border-bottom:1px solid #e5e7eb;font-size:13px;">
              <span style="color:#6b7280;font-weight:500;">Event</span><br>
              <span style="color:#0f172a;">${escapeHtml(eventTitle)}</span>
            </td>
          </tr>
          <tr>
            <td style="padding:12px 16px;font-size:13px;">
              <span style="color:#6b7280;font-weight:500;">Originally scheduled</span><br>
              <span style="color:#0f172a;">${escapeHtml(eventStartsAtFormatted)}</span>
            </td>
          </tr>
        </table>

        <hr style="border:none;border-top:1px solid #e5e7eb;margin:0 0 16px;">
        <p style="margin:0;color:#6b7280;font-size:12px;line-height:1.6;">— The Tribely team</p>
      </td></tr>
    </table>
  </body>
</html>`;

  return { subject, text, html };
};
