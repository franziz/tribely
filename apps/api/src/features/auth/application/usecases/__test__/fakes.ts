import type { TxContext, UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { DomainEvent } from '@/core/events/domain-event.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { User } from '@/features/users/domain/entities/user.js';
import type { Email } from '@/features/users/domain/value-objects/email.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import type { EmailVerificationToken } from '../../../domain/entities/email-verification-token.js';
import type { Clock } from '../../../domain/ports/clock.port.js';
import type {
  GeneratedVerificationCode,
  VerificationCodeHasher,
} from '../../../domain/ports/verification-code-hasher.port.js';
import type { EmailVerificationTokenRepository } from '../../../domain/repositories/email-verification-token.repository.js';

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
