import { Hono } from 'hono';
import { requireAuth, type AuthVariables } from '@/core/middleware/require-auth.js';
import { requireVerifiedEmail } from '@/core/middleware/require-verified-email.js';
import type { AccessTokenIssuer } from '@/features/auth/domain/ports/access-token-issuer.port.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import type { ListPendingReviewPromptsUseCase } from '../../../application/usecases/list-pending-review-prompts.usecase.js';
import { PendingReviewPromptsController } from '../controllers/pending-review-prompts.controller.js';

export interface PendingReviewPromptsRouteDeps {
  listPendingReviewPrompts: ListPendingReviewPromptsUseCase;
  accessTokens: AccessTokenIssuer;
  userRepository: UserRepository;
}

export const buildPendingReviewPromptsRoutes = (
  deps: PendingReviewPromptsRouteDeps,
): Hono<{ Variables: AuthVariables }> => {
  const controller = new PendingReviewPromptsController(deps.listPendingReviewPrompts);
  const auth = requireAuth(deps.accessTokens);
  const verifiedEmail = requireVerifiedEmail(deps.userRepository);

  // Mounted at /me in app.ts — so the local path is /pending-review-prompts,
  // resolving to GET /me/pending-review-prompts at the application level.
  return new Hono<{ Variables: AuthVariables }>().get(
    '/pending-review-prompts',
    auth,
    verifiedEmail,
    (c) => controller.getPrompt(c),
  );
};
