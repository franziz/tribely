import { beforeEach, describe, expect, it } from 'vitest';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type {
  EventAuditLogRecord,
  EventAuditLogRepository,
} from '../../../domain/repositories/event-audit-log.repository.js';
import { RecordEventDispatchUseCase } from '../record-event-dispatch.usecase.js';

class FakeEventAuditLogRepository implements EventAuditLogRepository {
  readonly recorded: EventAuditLogRecord[] = [];
  readonly contexts: Array<TxContext | undefined> = [];
  record(entries: EventAuditLogRecord[], ctx?: TxContext): Promise<void> {
    this.recorded.push(...entries);
    this.contexts.push(ctx);
    return Promise.resolve();
  }
}

describe('RecordEventDispatchUseCase', () => {
  let repo: FakeEventAuditLogRepository;
  let useCase: RecordEventDispatchUseCase;

  beforeEach(() => {
    repo = new FakeEventAuditLogRepository();
    useCase = new RecordEventDispatchUseCase(repo);
  });

  it('records dispatched success with no errorMessage', async () => {
    await useCase.execute({
      requestId: 'req-x',
      eventSeq: 42n,
      eventType: 'auth.userSignedIn',
      consumerName: 'auth.logUserSignedIn',
      phase: 'dispatched',
      attempt: 1,
      errorMessage: null,
    });

    expect(repo.recorded).toHaveLength(1);
    const r = repo.recorded[0];
    expect(r?.phase).toBe('dispatched');
    expect(r?.consumerName).toBe('auth.logUserSignedIn');
    expect(r?.errorMessage).toBeNull();
  });

  it('records failed phase with errorMessage', async () => {
    await useCase.execute({
      requestId: null,
      eventSeq: 7n,
      eventType: 'users.userRegistered',
      consumerName: 'auth.issueEmailVerificationOnUserRegistered',
      phase: 'failed',
      attempt: 3,
      errorMessage: 'Resend send failed: rate_limit_exceeded',
    });

    expect(repo.recorded[0]?.phase).toBe('failed');
    expect(repo.recorded[0]?.attempt).toBe(3);
    expect(repo.recorded[0]?.errorMessage).toContain('rate_limit_exceeded');
  });

  it('records blocked phase when consumer hits maxAttempts', async () => {
    await useCase.execute({
      requestId: 'req-y',
      eventSeq: 9n,
      eventType: 'users.userRegistered',
      consumerName: 'auth.issueEmailVerificationOnUserRegistered',
      phase: 'blocked',
      attempt: 5,
      errorMessage: 'still failing',
    });

    expect(repo.recorded[0]?.phase).toBe('blocked');
    expect(repo.recorded[0]?.attempt).toBe(5);
  });

  it('runs in its own transaction (no ctx passed)', async () => {
    await useCase.execute({
      requestId: null,
      eventSeq: 1n,
      eventType: 'x.y',
      consumerName: 'a.b',
      phase: 'dispatched',
      attempt: 1,
      errorMessage: null,
    });
    expect(repo.contexts).toEqual([undefined]);
  });
});
