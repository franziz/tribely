import type { UserBlockRepository } from '../../domain/repositories/user-block.repository.js';
import type { UserBlock } from '../../domain/entities/user-block.js';

export interface ListMyBlocksInput {
  initiatorUserId: string;
  cursor?: string;
  limit?: number;
}

export interface ListMyBlocksResult {
  rows: UserBlock[];
  nextCursor: string | null;
}

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 100;

/**
 * List blocks initiated by the authenticated user, cursor-paginated.
 */
export class ListMyBlocksUseCase {
  constructor(private readonly userBlocks: UserBlockRepository) {}

  async execute(input: ListMyBlocksInput): Promise<ListMyBlocksResult> {
    const limit = Math.min(input.limit ?? DEFAULT_LIMIT, MAX_LIMIT);

    return this.userBlocks.listInitiatedBy({
      initiatorUserId: input.initiatorUserId,
      ...(input.cursor ? { cursor: input.cursor } : {}),
      limit,
    });
  }
}
