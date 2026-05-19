import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { Credential } from '../entities/credential.js';

export interface CredentialRepository {
  findByUserId(userId: string, ctx?: TxContext): Promise<Credential | null>;
  save(credential: Credential, ctx?: TxContext): Promise<void>;
  /**
   * Hard-delete the credential row for the given user.
   * Used exclusively in the account-deletion cascade — NOT for sign-out.
   * The credential PK is userId, so this removes exactly one row.
   */
  deleteForUser(userId: string, ctx: TxContext): Promise<void>;
}
