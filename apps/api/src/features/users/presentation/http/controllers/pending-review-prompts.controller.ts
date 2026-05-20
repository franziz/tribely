import type { Context } from 'hono';
import type { AuthVariables } from '@/core/middleware/require-auth.js';
import type { ListPendingReviewPromptsUseCase } from '../../../application/usecases/list-pending-review-prompts.usecase.js';

export class PendingReviewPromptsController {
  constructor(private readonly listPendingReviewPrompts: ListPendingReviewPromptsUseCase) {}

  getPrompt = async (c: Context<{ Variables: AuthVariables }>) => {
    const viewerId = c.var.userId;
    const result = await this.listPendingReviewPrompts.execute({ viewerId });
    return c.json(result, 200);
  };
}
