import { beforeEach, describe, expect, it } from 'vitest';
import { runWithContext } from '@/core/context/request-context.js';
import { runAsSystem } from '@/core/context/system-context.js';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import { TEST_TX } from '@/core/testing/fakes.js';
import type {
  ModerationActionAuditRecord,
  ModerationActionAuditRepository,
} from '../../domain/repositories/moderation-action-audit.repository.js';
import {
  RecordModerationActionUseCase,
  type RecordModerationActionInput,
} from './record-moderation-action.usecase.js';

class FakeModerationActionAuditRepository implements ModerationActionAuditRepository {
  readonly recorded: ModerationActionAuditRecord[] = [];
  record(entry: ModerationActionAuditRecord, _ctx: TxContext): Promise<void> {
    this.recorded.push(entry);
    return Promise.resolve();
  }
  severOriginatingReportId(_id: string, _ctx: TxContext): Promise<number> {
    return Promise.resolve(0);
  }
}

describe('RecordModerationActionUseCase', () => {
  let repo: FakeModerationActionAuditRepository;
  let useCase: RecordModerationActionUseCase;

  const TOUCH_INPUT: RecordModerationActionInput = {
    operatorUserId: 'op_1',
    action: 'touch',
    reportId: 'report_1',
    targetType: 'review',
    targetId: 'review_1',
    reason: null,
    contentSnapshot: null,
    reporterUserId: 'reporter_1',
    reasonCode: null,
    justificationText: null,
    originatingReportId: null,
    actedAt: new Date('2026-05-24T10:00:00Z'),
  };

  const RESOLVE_HIDDEN_INPUT: RecordModerationActionInput = {
    operatorUserId: 'op_2',
    action: 'resolve_hidden',
    reportId: 'report_2',
    targetType: 'review',
    targetId: 'review_2',
    reason: 'Content violates community guidelines',
    contentSnapshot: '{"rating":1,"body":"offensive text"}',
    reporterUserId: 'reporter_2',
    reasonCode: null,
    justificationText: null,
    originatingReportId: null,
    actedAt: new Date('2026-05-24T11:00:00Z'),
  };

  beforeEach(() => {
    repo = new FakeModerationActionAuditRepository();
    useCase = new RecordModerationActionUseCase(repo);
  });

  it('(a) records a touch action with null reason and null contentSnapshot', async () => {
    await useCase.execute(TOUCH_INPUT, TEST_TX);

    expect(repo.recorded).toHaveLength(1);
    const row = repo.recorded[0];
    expect(row).toBeDefined();
    if (!row) return; // type-narrows for subsequent assertions; unreachable due to expect above
    expect(row.action).toBe('touch');
    expect(row.reason).toBeNull();
    expect(row.contentSnapshot).toBeNull();
    expect(row.operatorUserId).toBe('op_1');
    expect(row.reportId).toBe('report_1');
    expect(row.targetType).toBe('review');
    expect(row.targetId).toBe('review_1');
    expect(row.reporterUserId).toBe('reporter_1');
    expect(row.actedAt).toEqual(TOUCH_INPUT.actedAt);
    expect(row.id).toMatch(/^[a-z0-9]{8,}$/i);
    expect(row.recordedAt).toBeInstanceOf(Date);
  });

  it('(b) records a resolve_hidden action with all fields populated', async () => {
    await useCase.execute(RESOLVE_HIDDEN_INPUT, TEST_TX);

    expect(repo.recorded).toHaveLength(1);
    const row = repo.recorded[0];
    expect(row).toBeDefined();
    if (!row) return; // type-narrows for subsequent assertions; unreachable due to expect above
    expect(row.action).toBe('resolve_hidden');
    expect(row.reason).toBe('Content violates community guidelines');
    expect(row.contentSnapshot).toBe('{"rating":1,"body":"offensive text"}');
    expect(row.operatorUserId).toBe('op_2');
    expect(row.reportId).toBe('report_2');
    expect(row.targetType).toBe('review');
    expect(row.targetId).toBe('review_2');
    expect(row.reporterUserId).toBe('reporter_2');
    expect(row.actedAt).toEqual(RESOLVE_HIDDEN_INPUT.actedAt);
    expect(row.id).toMatch(/^[a-z0-9]{8,}$/i);
  });

  it('(c) captures requestId from an active ALS context frame', async () => {
    await runWithContext({ requestId: 'req-moderation-001', actorUserId: 'op_1' }, async () => {
      await useCase.execute(TOUCH_INPUT, TEST_TX);
    });

    expect(repo.recorded).toHaveLength(1);
    expect(repo.recorded[0]?.requestId).toBe('req-moderation-001');
  });

  it('(d) records requestId as null when called outside any ALS frame', async () => {
    await useCase.execute(TOUCH_INPUT, TEST_TX);

    expect(repo.recorded).toHaveLength(1);
    expect(repo.recorded[0]?.requestId).toBeNull();
  });

  it('(e) captures system: requestId when wrapped in runAsSystem for CLI callers', async () => {
    await runAsSystem('cli.moderation.touch', async () => {
      await useCase.execute(TOUCH_INPUT, TEST_TX);
    });

    expect(repo.recorded).toHaveLength(1);
    expect(repo.recorded[0]?.requestId).toMatch(/^system:cli\.moderation\.touch:/);
  });

  it('(f) passes the supplied TxContext through to the repository', async () => {
    const contexts: TxContext[] = [];
    const capturingRepo: ModerationActionAuditRepository = {
      record(entry, ctx) {
        contexts.push(ctx);
        return Promise.resolve();
      },
      severOriginatingReportId(_id, _ctx) {
        return Promise.resolve(0);
      },
    };
    const sut = new RecordModerationActionUseCase(capturingRepo);

    await sut.execute(TOUCH_INPUT, TEST_TX);

    expect(contexts).toHaveLength(1);
    expect(contexts[0]).toBe(TEST_TX);
  });
});
