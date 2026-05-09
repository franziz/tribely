import type { DomainEvent } from '@/core/events/domain-event.js';

export const CREDENTIAL_ISSUED = 'auth.credentialIssued' as const;

export interface CredentialIssuedPayload {
  userId: string;
  issuedAt: string;
}

export type CredentialIssuedEvent = DomainEvent<CredentialIssuedPayload> & {
  type: typeof CREDENTIAL_ISSUED;
};

export const credentialIssued = (payload: CredentialIssuedPayload): CredentialIssuedEvent => ({
  type: CREDENTIAL_ISSUED,
  aggregateType: 'Credential',
  aggregateId: payload.userId,
  payload,
  version: 1,
});
