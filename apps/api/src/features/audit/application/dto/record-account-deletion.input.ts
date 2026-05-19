import type {
  AccountDeletionCascadeScope,
  AccountDeletionOutcome,
} from '../../domain/repositories/account-deletion-event.repository.js';

export interface RecordAccountDeletionInput {
  /** Raw userId — will be SHA-256 hashed before writing; plaintext is never persisted. */
  userId: string;
  requestedAt: Date;
  completedAt: Date;
  cascadeScope: AccountDeletionCascadeScope[];
  outcome: AccountDeletionOutcome;
  failureReason?: string | null;
}
