import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { Credential } from '../entities/credential.js';

export interface CredentialRepository {
  findByUserId(userId: string, ctx?: TxContext): Promise<Credential | null>;
  save(credential: Credential, ctx?: TxContext): Promise<void>;
}
