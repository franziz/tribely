import { describe, expect, it, vi } from 'vitest';
import { createId } from '@paralleldrive/cuid2';
import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { ReportRepository } from '../../domain/repositories/report.repository.js';
import { CascadeReportsOnUserDeletionUseCase } from './cascade-reports-on-user-deletion.usecase.js';

describe('CascadeReportsOnUserDeletionUseCase', () => {
  it('delegates to deleteAllForUser with the correct userId and ctx', async () => {
    const deleteAllForUser = vi.fn().mockResolvedValue(2);
    const reports: ReportRepository = {
      save: vi.fn(),
      findById: vi.fn(),
      listUnresolved: vi.fn(),
      listOlderThan: vi.fn(),
      listOpenOlderThan: vi.fn(),
      listByReporter: vi.fn(),
      deleteAllForUser,
    };
    const useCase = new CascadeReportsOnUserDeletionUseCase(reports);

    const userId = createId();
    const ctx = {} as TxContext;

    await useCase.execute({ userId }, ctx);

    expect(deleteAllForUser).toHaveBeenCalledOnce();
    expect(deleteAllForUser).toHaveBeenCalledWith(userId, ctx);
  });
});
