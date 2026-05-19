import { beforeEach, describe, expect, it } from 'vitest';
import type {
  HttpAuditLogRecord,
  HttpAuditLogRepository,
} from '../../domain/repositories/http-audit-log.repository.js';
import { RecordHttpCallUseCase } from './record-http-call.usecase.js';

class FakeHttpAuditLogRepository implements HttpAuditLogRepository {
  readonly recorded: HttpAuditLogRecord[] = [];
  record(entry: HttpAuditLogRecord): Promise<void> {
    this.recorded.push(entry);
    return Promise.resolve();
  }
}

describe('RecordHttpCallUseCase', () => {
  let repo: FakeHttpAuditLogRepository;
  let useCase: RecordHttpCallUseCase;

  beforeEach(() => {
    repo = new FakeHttpAuditLogRepository();
    useCase = new RecordHttpCallUseCase(repo);
  });

  it('records one row with the provided fields and a generated id', async () => {
    const receivedAt = new Date('2026-05-10T12:00:00Z');
    await useCase.execute({
      requestId: 'req-001',
      method: 'POST',
      path: '/auth/sign-up',
      status: 201,
      durationMs: 42,
      actorUserId: null,
      ip: '203.0.113.5',
      userAgent: 'tribely-mobile/1.0',
      errorCode: null,
      receivedAt,
    });

    expect(repo.recorded).toHaveLength(1);
    const row = repo.recorded[0];
    expect(row).toBeDefined();
    expect(row?.requestId).toBe('req-001');
    expect(row?.status).toBe(201);
    expect(row?.actorUserId).toBeNull();
    expect(row?.errorCode).toBeNull();
    expect(row?.receivedAt).toEqual(receivedAt);
    expect(row?.id).toMatch(/^[a-z0-9]{8,}$/i);
  });

  it('captures errorCode for 4xx/5xx responses', async () => {
    await useCase.execute({
      requestId: 'req-002',
      method: 'POST',
      path: '/auth/sign-in',
      status: 401,
      durationMs: 18,
      actorUserId: null,
      ip: null,
      userAgent: null,
      errorCode: 'UNAUTHORIZED',
      receivedAt: new Date(),
    });

    expect(repo.recorded[0]?.status).toBe(401);
    expect(repo.recorded[0]?.errorCode).toBe('UNAUTHORIZED');
  });
});
