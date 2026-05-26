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
  countExternalInputs(_reportId: string, _ctx?: TxContext): Promise<number> {
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

  const ESCALATE_INPUT: RecordModerationActionInput = {
    operatorUserId: 'op_3',
    action: 'escalate',
    reportId: 'report_3',
    targetType: 'review',
    targetId: 'review_3',
    reason: 'Escalating due to potential criminal content',
    contentSnapshot: null,
    reporterUserId: 'reporter_3',
    reasonCode: null,
    justificationText: null,
    originatingReportId: null,
    escalationCategory: 'criminal-content',
    externalRef: 'SGP-CASE-2026-001',
    actedAt: new Date('2026-05-24T12:00:00Z'),
  };

  const RECORD_EXTERNAL_INPUT: RecordModerationActionInput = {
    operatorUserId: 'op_4',
    action: 'record_external_input',
    reportId: 'report_3',
    targetType: 'review',
    targetId: 'review_3',
    reason: null,
    contentSnapshot: null,
    reporterUserId: 'reporter_3',
    reasonCode: null,
    justificationText: null,
    originatingReportId: null,
    externalSource: 'imda',
    externalDisposition: 'No further action required.',
    externalReceivedAt: new Date('2026-05-20T08:00:00Z'),
    actedAt: new Date('2026-05-24T13:00:00Z'),
  };

  const RESOLVE_WITH_OVERRIDE_INPUT: RecordModerationActionInput = {
    operatorUserId: 'op_5',
    action: 'resolve_with_override',
    reportId: 'report_3',
    targetType: 'review',
    targetId: 'review_3',
    reason: 'Overriding based on external guidance',
    contentSnapshot: null,
    reporterUserId: 'reporter_3',
    reasonCode: null,
    justificationText: null,
    originatingReportId: null,
    escalationCategory: 'criminal-content',
    actedAt: new Date('2026-05-24T14:00:00Z'),
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
      countExternalInputs(_reportId, _ctx) {
        return Promise.resolve(0);
      },
    };
    const sut = new RecordModerationActionUseCase(capturingRepo);

    await sut.execute(TOUCH_INPUT, TEST_TX);

    expect(contexts).toHaveLength(1);
    expect(contexts[0]).toBe(TEST_TX);
  });

  it('(g) records an escalate action with escalationCategory and externalRef', async () => {
    await useCase.execute(ESCALATE_INPUT, TEST_TX);

    expect(repo.recorded).toHaveLength(1);
    const row = repo.recorded[0];
    expect(row).toBeDefined();
    if (!row) return;
    expect(row.action).toBe('escalate');
    expect(row.escalationCategory).toBe('criminal-content');
    expect(row.externalRef).toBe('SGP-CASE-2026-001');
    expect(row.externalSource).toBeNull();
    expect(row.externalDisposition).toBeNull();
    expect(row.externalReceivedAt).toBeNull();
  });

  it('(h) records a record_external_input action with externalSource, externalDisposition, and externalReceivedAt', async () => {
    await useCase.execute(RECORD_EXTERNAL_INPUT, TEST_TX);

    expect(repo.recorded).toHaveLength(1);
    const row = repo.recorded[0];
    expect(row).toBeDefined();
    if (!row) return;
    expect(row.action).toBe('record_external_input');
    expect(row.externalSource).toBe('imda');
    expect(row.externalDisposition).toBe('No further action required.');
    expect(row.externalReceivedAt).toEqual(new Date('2026-05-20T08:00:00Z'));
    // actedAt is the CLI invocation clock — distinct from externalReceivedAt
    expect(row.actedAt).toEqual(new Date('2026-05-24T13:00:00Z'));
    expect(row.escalationCategory).toBeNull();
    expect(row.externalRef).toBeNull();
  });

  it('(i) records a resolve_with_override action with escalationCategory carried forward', async () => {
    await useCase.execute(RESOLVE_WITH_OVERRIDE_INPUT, TEST_TX);

    expect(repo.recorded).toHaveLength(1);
    const row = repo.recorded[0];
    expect(row).toBeDefined();
    if (!row) return;
    expect(row.action).toBe('resolve_with_override');
    expect(row.escalationCategory).toBe('criminal-content');
    expect(row.externalRef).toBeNull();
    expect(row.externalSource).toBeNull();
    expect(row.externalDisposition).toBeNull();
    expect(row.externalReceivedAt).toBeNull();
  });

  it('(j) defaults all five new optional fields to null when not supplied', async () => {
    await useCase.execute(TOUCH_INPUT, TEST_TX);

    const row = repo.recorded[0];
    expect(row).toBeDefined();
    if (!row) return;
    expect(row.escalationCategory).toBeNull();
    expect(row.externalRef).toBeNull();
    expect(row.externalSource).toBeNull();
    expect(row.externalDisposition).toBeNull();
    expect(row.externalReceivedAt).toBeNull();
  });
});
