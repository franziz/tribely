import type { ConsumerRegistry } from '@/core/events/consumer-registry.js';
import type { EmailSender } from '@/core/email/email-sender.port.js';
import type { EventRepository } from '@/features/events/domain/repositories/event.repository.js';
import { sendSafetyReportEmailOnCheckInFlagged } from './send-safety-report-email-on-check-in-flagged.consumer.js';

export interface CheckInsConsumerDeps {
  emailSender: EmailSender;
  eventRepository: EventRepository;
}

/**
 * Register every consumer the `check-ins` feature owns. Called once at boot
 * from buildContainer(). Other features that care about check-ins' events
 * register their consumers from their own presentation/events/index.ts —
 * not here.
 */
export const registerCheckInsConsumers = (
  registry: ConsumerRegistry,
  deps: CheckInsConsumerDeps,
): void => {
  registry.register(
    sendSafetyReportEmailOnCheckInFlagged({
      emailSender: deps.emailSender,
      eventRepository: deps.eventRepository,
    }),
  );
};
