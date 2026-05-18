import type { TxContext, UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { DomainEvent } from '@/core/events/domain-event.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { Logger } from '@/core/observability/logger.port.js';
import type { User } from '@/features/users/domain/entities/user.js';
import type { Email } from '@/features/users/domain/value-objects/email.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import type { Credential } from '../../domain/entities/credential.js';
import type { EmailVerificationToken } from '../../domain/entities/email-verification-token.js';
import type { PasswordResetToken } from '../../domain/entities/password-reset-token.js';
import type { RefreshToken } from '../../domain/entities/refresh-token.js';
import type { Clock } from '../../domain/ports/clock.port.js';
import type { PasswordHasher } from '../../domain/ports/password-hasher.port.js';
import type {
  GeneratedVerificationCode,
  VerificationCodeHasher,
} from '../../domain/ports/verification-code-hasher.port.js';
import type { CredentialRepository } from '../../domain/repositories/credential.repository.js';
import type { EmailVerificationTokenRepository } from '../../domain/repositories/email-verification-token.repository.js';
import type { PasswordResetTokenRepository } from '../../domain/repositories/password-reset-token.repository.js';
import type { RefreshTokenRepository } from '../../domain/repositories/refresh-token.repository.js';
import type { RefreshTokenRevokedReason } from '../../domain/events/refresh-token-revoked.event.js';
import { HashedPassword } from '../../domain/value-objects/hashed-password.js';
import type { Password } from '../../domain/value-objects/password.js';

/** Marker used by the fake UoW; domain code treats TxContext as opaque. */
const TEST_TX: TxContext = { __brand: 'TxContext' };

export class FakeUnitOfWork implements UnitOfWork {
  async run<T>(work: (ctx: TxContext) => Promise<T>): Promise<T> {
    return work(TEST_TX);
  }
}

export class FakeEventPublisher implements EventPublisher {
  readonly published: DomainEvent[] = [];
  publish(_ctx: TxContext, ...events: DomainEvent[]): Promise<void> {
    this.published.push(...events);
    return Promise.resolve();
  }
}

export class FixedClock implements Clock {
  constructor(private current: Date) {}
  now(): Date {
    return this.current;
  }
  advance(ms: number): void {
    this.current = new Date(this.current.getTime() + ms);
  }
  set(at: Date): void {
    this.current = at;
  }
}

export class FakeUserRepository implements UserRepository {
  private readonly byId = new Map<string, User>();

  put(user: User): void {
    this.byId.set(user.id, user);
  }

  findById(id: string): Promise<User | null> {
    return Promise.resolve(this.byId.get(id) ?? null);
  }

  findByEmail(email: Email): Promise<User | null> {
    for (const user of this.byId.values()) {
      if (user.email.equals(email)) return Promise.resolve(user);
    }
    return Promise.resolve(null);
  }

  save(user: User): Promise<void> {
    this.byId.set(user.id, user);
    return Promise.resolve();
  }
}

export class FakeEmailVerificationTokenRepository implements EmailVerificationTokenRepository {
  private readonly byId = new Map<string, EmailVerificationToken>();

  put(token: EmailVerificationToken): void {
    this.byId.set(token.id, token);
  }

  all(): EmailVerificationToken[] {
    return Array.from(this.byId.values());
  }

  findById(id: string): Promise<EmailVerificationToken | null> {
    return Promise.resolve(this.byId.get(id) ?? null);
  }

  findOpenByUserId(userId: string): Promise<EmailVerificationToken | null> {
    // Mirrors the Prisma where filter (consumed/invalidated) but skips the
    // expiry check — the use case re-validates isOpen() against its own
    // Clock, so leaving expiry to the aggregate keeps tests independent of
    // real wall-clock time.
    const open = Array.from(this.byId.values())
      .filter((t) => t.userId === userId && !t.isConsumed() && !t.invalidated)
      .sort((a, b) => b.issuedAt.getTime() - a.issuedAt.getTime());
    return Promise.resolve(open[0] ?? null);
  }

  save(token: EmailVerificationToken): Promise<void> {
    this.byId.set(token.id, token);
    return Promise.resolve();
  }
}

export class FakePasswordResetTokenRepository implements PasswordResetTokenRepository {
  private readonly byId = new Map<string, PasswordResetToken>();

  put(token: PasswordResetToken): void {
    this.byId.set(token.id, token);
  }

  all(): PasswordResetToken[] {
    return Array.from(this.byId.values());
  }

  findById(id: string): Promise<PasswordResetToken | null> {
    return Promise.resolve(this.byId.get(id) ?? null);
  }

  findOpenByUserId(userId: string): Promise<PasswordResetToken | null> {
    // Mirrors the Prisma where filter (consumed/invalidated) but skips the
    // expiry check — the use case re-validates isOpen() against its own
    // Clock, so leaving expiry to the aggregate keeps tests independent of
    // real wall-clock time.
    const open = Array.from(this.byId.values())
      .filter((t) => t.userId === userId && !t.isConsumed() && !t.invalidated)
      .sort((a, b) => b.issuedAt.getTime() - a.issuedAt.getTime());
    return Promise.resolve(open[0] ?? null);
  }

  save(token: PasswordResetToken): Promise<void> {
    this.byId.set(token.id, token);
    return Promise.resolve();
  }
}

export interface RecordedLog {
  level: 'info' | 'warn' | 'error';
  payload: Record<string, unknown>;
  message: string;
}

export class FakeLogger implements Logger {
  readonly logs: RecordedLog[] = [];
  info(payload: Record<string, unknown>, message: string): void {
    this.logs.push({ level: 'info', payload, message });
  }
  warn(payload: Record<string, unknown>, message: string): void {
    this.logs.push({ level: 'warn', payload, message });
  }
  error(payload: Record<string, unknown>, message: string): void {
    this.logs.push({ level: 'error', payload, message });
  }
}

export class FakeCredentialRepository implements CredentialRepository {
  private readonly byUserId = new Map<string, Credential>();

  put(credential: Credential): void {
    this.byUserId.set(credential.userId, credential);
  }

  findByUserId(userId: string): Promise<Credential | null> {
    return Promise.resolve(this.byUserId.get(userId) ?? null);
  }

  save(credential: Credential): Promise<void> {
    this.byUserId.set(credential.userId, credential);
    return Promise.resolve();
  }
}

export class FakeRefreshTokenRepository implements RefreshTokenRepository {
  private readonly byId = new Map<string, RefreshToken>();
  private readonly byHash = new Map<string, string>();

  put(token: RefreshToken): void {
    this.byId.set(token.id, token);
    this.byHash.set(token.tokenHash, token.id);
  }

  all(): RefreshToken[] {
    return Array.from(this.byId.values());
  }

  findByTokenHash(hash: string): Promise<RefreshToken | null> {
    const id = this.byHash.get(hash);
    if (!id) return Promise.resolve(null);
    return Promise.resolve(this.byId.get(id) ?? null);
  }

  findById(id: string): Promise<RefreshToken | null> {
    return Promise.resolve(this.byId.get(id) ?? null);
  }

  save(token: RefreshToken): Promise<void> {
    this.byId.set(token.id, token);
    this.byHash.set(token.tokenHash, token.id);
    return Promise.resolve();
  }

  revokeAllActiveForUser(
    userId: string,
    reason: RefreshTokenRevokedReason,
    now: Date,
  ): Promise<RefreshToken[]> {
    const revoked: RefreshToken[] = [];
    for (const token of this.byId.values()) {
      if (token.userId !== userId) continue;
      if (token.isRevoked()) continue;
      token.revoke(reason, now);
      revoked.push(token);
    }
    return Promise.resolve(revoked);
  }
}

/**
 * Deterministic password hasher for tests: hash is `argon2:` + plaintext.
 * `verify` is exact-string match. Skips real argon2 — slow + nondeterministic
 * salts make assertions flaky.
 */
export class FakePasswordHasher implements PasswordHasher {
  hash(plaintext: Password): Promise<HashedPassword> {
    return Promise.resolve(HashedPassword.fromHash(`argon2:${plaintext.value}`));
  }

  verify(plaintext: Password, hashed: HashedPassword): Promise<boolean> {
    return Promise.resolve(hashed.value === `argon2:${plaintext.value}`);
  }
}

/**
 * Deterministic hasher: hash is `h:` + plaintext. Lets tests assert the
 * persisted codeHash without recomputing SHA-256, while still verifying the
 * use case calls `.hash(plaintext)` on the incoming code at verify time.
 */
export class FakeVerificationCodeHasher implements VerificationCodeHasher {
  private readonly queue: string[] = [];

  enqueue(...codes: string[]): void {
    this.queue.push(...codes);
  }

  generate(): GeneratedVerificationCode {
    const plaintext = this.queue.shift() ?? '111111';
    return { plaintext, hash: this.hash(plaintext) };
  }

  hash(plaintext: string): string {
    return `h:${plaintext}`;
  }
}
