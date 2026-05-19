import type { Context } from 'hono';
import type { BlockUserUseCase } from '../../../application/usecases/block-user.usecase.js';
import type { UnblockUserUseCase } from '../../../application/usecases/unblock-user.usecase.js';
import type { ListMyBlocksUseCase } from '../../../application/usecases/list-my-blocks.usecase.js';
import type { BlockUserBody, ListMyBlocksQuery } from '../schemas/user-block.schemas.js';

export class UserBlockController {
  constructor(
    private readonly blockUser: BlockUserUseCase,
    private readonly unblockUser: UnblockUserUseCase,
    private readonly listMyBlocks: ListMyBlocksUseCase,
  ) {}

  /**
   * POST /me/blocks — block a user.
   */
  blockAction = async (c: Context, actorUserId: string, body: BlockUserBody) => {
    const block = await this.blockUser.execute({
      initiatorUserId: actorUserId,
      blockedUserId: body.blockedUserId,
    });

    return c.json(
      {
        block: {
          id: block.id,
          initiatorUserId: block.initiatorUserId,
          blockedUserId: block.blockedUserId,
          createdAt: block.createdAt.toISOString(),
        },
      },
      200,
    );
  };

  /**
   * DELETE /me/blocks/:blockedUserId — unblock a user.
   */
  unblockAction = async (c: Context, actorUserId: string, blockedUserId: string) => {
    await this.unblockUser.execute({
      initiatorUserId: actorUserId,
      blockedUserId,
    });
    return c.body(null, 204);
  };

  /**
   * GET /me/blocks — list my blocks (paginated).
   */
  listAction = async (c: Context, actorUserId: string, query: ListMyBlocksQuery) => {
    const result = await this.listMyBlocks.execute({
      initiatorUserId: actorUserId,
      ...(query.cursor !== undefined && { cursor: query.cursor }),
      limit: query.limit,
    });

    return c.json(
      {
        rows: result.rows.map((b) => ({
          id: b.id,
          blockedUserId: b.blockedUserId,
          createdAt: b.createdAt.toISOString(),
        })),
        nextCursor: result.nextCursor,
      },
      200,
    );
  };
}
