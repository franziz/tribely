import type { EventBus } from '@/core/events/event-bus.port.js';
import { logger } from '@/core/middleware/logger.js';
import {
  CREDENTIAL_ISSUED,
  type CredentialIssuedEvent,
} from '../../domain/events/credential-issued.event.js';
import {
  USER_SIGNED_IN,
  type UserSignedInEvent,
} from '../../domain/events/user-signed-in.event.js';

export const registerAuthSubscribers = (bus: EventBus): void => {
  bus.subscribe<CredentialIssuedEvent>(CREDENTIAL_ISSUED, (event) => {
    logger.info({ userId: event.payload.userId }, 'auth.credentialIssued');
  });
  bus.subscribe<UserSignedInEvent>(USER_SIGNED_IN, (event) => {
    logger.info({ userId: event.payload.userId }, 'auth.userSignedIn');
  });
};
