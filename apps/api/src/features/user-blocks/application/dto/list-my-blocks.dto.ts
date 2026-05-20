import type { UserBlock } from '../../domain/entities/user-block.js';

export interface ListMyBlocksResult {
  rows: UserBlock[];
  nextCursor: string | null;
}
