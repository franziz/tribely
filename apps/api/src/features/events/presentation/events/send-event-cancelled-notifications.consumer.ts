import type { EmailSender } from '@/core/email/email-sender.port.js';
import { eventCancelledEmail } from '@/core/email/templates/event-cancelled.template.js';
import type { Consumer } from '@/core/events/consumer.port.js';
import {
  EVENT_CANCELLED,
  type EventCancelledEvent,
} from '../../domain/events/event-cancelled.event.js';
import type { EventRepository } from '../../domain/repositories/event.repository.js';
import type { JoinRequestRepository } from '@/features/join-requests/domain/repositories/join-request.repository.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';

export interface SendEventCancelledNotificationsDeps {
  emailSender: EmailSender;
  eventRepository: EventRepository;
  joinRequestRepository: JoinRequestRepository;
  userRepository: UserRepository;
}

/**
 * Fan-out notification consumer: on every `events.eventCancelled` event,
 * sends an email to the host and all active joiners (approved + pending).
 *
 * Fires regardless of cancellation origin (host-initiated or moderator).
 * Email copy is legally-locked Option A — it does NOT mention the reason,
 * any reporter, or anything moderation-specific (TRI-193 AC #5).
 *
 * Idempotency note: this consumer is NOT idempotent with respect to email
 * delivery. At-least-once dispatch (bounded to 5 retry attempts) means a
 * transient failure before the consumer_offsets commit can result in
 * duplicate emails. This is documented accepted risk for launch — duplicates
 * are a user-experience nuisance, not a legal or data-integrity incident.
 * A notification-audit table (TRI-159) will provide the dedup surface
 * post-launch. Do NOT introduce a dedupe guard here until that audit table
 * is in place.
 */
export const sendEventCancelledNotifications = (
  deps: SendEventCancelledNotificationsDeps,
): Consumer<EventCancelledEvent> => ({
  name: 'events.sendEventCancelledNotifications',
  topic: EVENT_CANCELLED,
  async handle(event) {
    const { eventId } = event.payload;

    // 1. Look up the event for title + startsAt.
    const found = await deps.eventRepository.findById(eventId);
    if (!found) {
      // Event not found — nothing to notify about. Could happen if the event
      // was hard-deleted between cancellation and dispatch (shouldn't occur in
      // production but guard defensively).
      return;
    }

    // 2. List all active joiners (approved + pending).
    const joinRequests = await deps.joinRequestRepository.findByEvent(eventId, {
      status: ['approved', 'pending'],
    });

    // 3. Collect the unique set of user IDs: host + all active joiners.
    const joinerUserIds = joinRequests.map((jr) => jr.requesterUserId);
    const allUserIds = [...new Set([found.hostUserId, ...joinerUserIds])];

    // 4. Resolve users in a single batch query.
    const users = await deps.userRepository.findByIds(allUserIds);

    // 5. Send one email per user with a non-null email address.
    const emailContent = eventCancelledEmail({
      eventTitle: found.title,
      eventStartsAt: found.startsAt,
    });

    await Promise.all(
      users
        .filter((u) => u.email.value.length > 0)
        .map((u) =>
          deps.emailSender.send({
            to: u.email.value,
            subject: emailContent.subject,
            html: emailContent.html,
            text: emailContent.text,
          }),
        ),
    );
  },
});
