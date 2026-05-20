import { describe, expect, it, vi } from 'vitest';
import { createId } from '@paralleldrive/cuid2';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { ReportRepository } from '../../domain/repositories/report.repository.js';
import { CascadeReportsOnUserDeletionUseCase } from './cascade-reports-on-user-deletion.usecase.js';

const makeReportRepo = (): ReportRepository => ({
  save: vi.fn(),
  findById: vi.fn(),
  listUnresolved: vi.fn(),
  listOlderThan: vi.fn(),
  listOpenOlderThan: vi.fn(),
  listByReporter: vi.fn(),
  deleteAllForUser: vi.fn().mockResolvedValue(2),
});

describe('CascadeReportsOnUserDeletionUseCase', () => {
  it('delegates to deleteAllForUser with the correct userId and ctx', async () => {
    const reports = makeReportRepo();
    const useCase = new CascadeReportsOnUserDeletionUseCase(reports);

    const userId = createId();
    const ctx = {} as TxContext;

    await useCase.execute({ userId }, ctx);

    expect(reports.deleteAllForUser).toHaveBeenCalledOnce();
    expect(reports.deleteAllForUser).toHaveBeenCalledWith(userId, ctx);
  });
});
