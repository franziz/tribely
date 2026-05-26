import type { ConsumerRegistry } from '@/core/events/consumer-registry.js';
import type { EmailSender } from '@/core/email/email-sender.port.js';
import type { EventRepository } from '../../domain/repositories/event.repository.js';
import type { JoinRequestRepository } from '@/features/join-requests/domain/repositories/join-request.repository.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import { sendEventCancelledNotifications } from './send-event-cancelled-notifications.consumer.js';

export interface EventsConsumerDeps {
  emailSender: EmailSender;
  eventRepository: EventRepository;
  joinRequestRepository: JoinRequestRepository;
  userRepository: UserRepository;
}

/**
 * Register every consumer the `events` feature owns. Called once at boot
 * from `buildContainer()`.
 */
export const registerEventsConsumers = (
  registry: ConsumerRegistry,
  deps: EventsConsumerDeps,
): void => {
  registry.register(sendEventCancelledNotifications(deps));
};
