import type { Consumer } from '@/core/events/consumer.port.js';
import { logger } from '@/core/middleware/logger.js';
import {
  CREDENTIAL_ISSUED,
  type CredentialIssuedEvent,
} from '../../domain/events/credential-issued.event.js';

export const logCredentialIssued = (): Consumer<CredentialIssuedEvent> => ({
  name: 'auth.logCredentialIssued',
  topic: CREDENTIAL_ISSUED,
  handle(event, ctx) {
    logger.info(
      { userId: event.payload.userId, requestId: ctx.requestId },
      'auth.credentialIssued',
    );
    return Promise.resolve();
  },
});
