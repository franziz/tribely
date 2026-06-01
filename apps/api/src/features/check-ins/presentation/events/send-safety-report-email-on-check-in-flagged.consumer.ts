import type { EmailSender } from '@/core/email/email-sender.port.js';
import { safetyReportTemplate } from '@/core/email/templates/safety-report.template.js';
import { env } from '@/core/config/env.js';
import type { Consumer } from '@/core/events/consumer.port.js';
import {
  CHECK_IN_FLAGGED,
  type CheckInFlaggedEvent,
} from '../../domain/events/check-in-flagged.event.js';
import type { EventRepository } from '@/features/events/domain/repositories/event.repository.js';

export interface SendSafetyReportEmailOnCheckInFlaggedDeps {
  emailSender: EmailSender;
  eventRepository: EventRepository;
}

const TITLE_MAX_DISPLAY = 40;

const truncateTitle = (title: string): string =>
  title.length > TITLE_MAX_DISPLAY ? `${title.slice(0, TITLE_MAX_DISPLAY)}…` : title;

/**
 * When a check-in is flagged, send a redacted safety-report email to
 * `safety@gotribely.com` (env: SAFETY_REPORT_EMAIL).
 *
 * Body uses IDs + free-text only — no display names, no avatar URLs, no
 * phone numbers, no email addresses. The destination mailbox is external
 * (PDPA s26 / out-of-region); PII stays in the SG-region DB.
 *
 * Idempotency: duplicate delivery of the same event sends a duplicate
 * email — acceptable. The safety mailbox operator deduplicates in the
 * inbox. No sent-at column or dedup guard is added (5-retry bound caps
 * worst-case duplicates; duplicate safety emails are not a real harm).
 */
export const sendSafetyReportEmailOnCheckInFlagged = (
  deps: SendSafetyReportEmailOnCheckInFlaggedDeps,
): Consumer<CheckInFlaggedEvent> => ({
  name: 'check-ins.sendSafetyReportEmailOnCheckInFlagged',
  topic: CHECK_IN_FLAGGED,
  async handle(event) {
    const {
      checkInId,
      userId,
      eventId,
      hostUserId,
      flaggedAt,
      reportBody,
      disclaimerAcknowledged,
    } = event.payload;

    const found = await deps.eventRepository.findById(eventId);
    const rawTitle = found?.title ?? eventId;
    const eventTitle = truncateTitle(rawTitle);

    const { subject, html, text } = safetyReportTemplate({
      checkInId,
      userId,
      eventId,
      eventTitle,
      hostUserId,
      flaggedAt,
      reportBody,
      disclaimerAcknowledged,
    });

    await deps.emailSender.send({
      to: env.SAFETY_REPORT_EMAIL,
      subject,
      html,
      text,
    });
  },
});
