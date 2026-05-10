import { beforeEach, describe, expect, it } from 'vitest';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type {
  EventAuditLogRecord,
  EventAuditLogRepository,
} from '../../../domain/repositories/event-audit-log.repository.js';
import { RecordEventPublishedUseCase } from '../record-event-published.usecase.js';

const TEST_TX: TxContext = { __brand: 'TxContext' };

class FakeEventAuditLogRepository implements EventAuditLogRepository {
  readonly recorded: EventAuditLogRecord[] = [];
  readonly contexts: Array<TxContext | undefined> = [];
  record(entries: EventAuditLogRecord[], ctx?: TxContext): Promise<void> {
    this.recorded.push(...entries);
    this.contexts.push(ctx);
    return Promise.resolve();
  }
}

describe('RecordEventPublishedUseCase', () => {
  let repo: FakeEventAuditLogRepository;
  let useCase: RecordEventPublishedUseCase;

  beforeEach(() => {
    repo = new FakeEventAuditLogRepository();
    useCase = new RecordEventPublishedUseCase(repo);
  });

  it('writes one published row per event, sharing the same requestId', async () => {
    await useCase.execute(
      [
        { requestId: 'req-1', eventSeq: 100n, eventType: 'users.userRegistered' },
        { requestId: 'req-1', eventSeq: 101n, eventType: 'auth.credentialIssued' },
      ],
      TEST_TX,
    );

    expect(repo.recorded).toHaveLength(2);
    expect(repo.recorded.every((r) => r.phase === 'published')).toBe(true);
    expect(repo.recorded.every((r) => r.consumerName === null)).toBe(true);
    expect(repo.recorded.every((r) => r.requestId === 'req-1')).toBe(true);
    expect(repo.recorded.map((r) => r.eventSeq)).toEqual([100n, 101n]);
  });

  it('passes the supplied TxContext through (atomic with outbox row)', async () => {
    await useCase.execute([{ requestId: null, eventSeq: 1n, eventType: 'x.y' }], TEST_TX);

    expect(repo.contexts).toEqual([TEST_TX]);
  });

  it('no-op on empty input', async () => {
    await useCase.execute([], TEST_TX);
    expect(repo.recorded).toHaveLength(0);
    expect(repo.contexts).toHaveLength(0);
  });
});
