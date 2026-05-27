import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { requireAuth, type AuthVariables } from '@/core/middleware/require-auth.js';
import type { AccessTokenIssuer } from '@/features/auth/domain/ports/access-token-issuer.port.js';
import type { SubmitSupportTicketUseCase } from '../../../application/usecases/submit-support-ticket.usecase.js';
import { submitSupportTicketBodySchema } from '../schemas/submit-support-ticket.schema.js';

export interface SupportRouteDeps {
  submitSupportTicket: SubmitSupportTicketUseCase;
  accessTokens: AccessTokenIssuer;
}

/**
 * POST /support/tickets
 *
 * Auth-gated: requires a valid JWT. No verified-email gate — support tickets
 * must be reachable even when the user cannot receive email (e.g., sign-in
 * issues are a primary support category).
 *
 * Rate-limit enforcement is domain-side (5 per 24h per user in
 * SubmitSupportTicketUseCase) rather than a middleware-level token-bucket.
 * This keeps the limit source-of-truth in one place and avoids the InMemory
 * rate-limiter resetting on each deploy.
 */
export const buildSupportRoutes = (deps: SupportRouteDeps): Hono<{ Variables: AuthVariables }> => {
  const auth = requireAuth(deps.accessTokens);

  return new Hono<{ Variables: AuthVariables }>().post(
    '/tickets',
    auth,
    zValidator('json', submitSupportTicketBodySchema),
    async (c) => {
      const userId = c.get('userId');
      const body = c.req.valid('json');

      const result = await deps.submitSupportTicket.execute({
        userId,
        category: body.category,
        message: body.message,
        ...(body.reportId !== undefined && { reportId: body.reportId }),
      });

      return c.json(
        {
          ticket: {
            id: result.id,
            createdAt: result.createdAt.toISOString(),
          },
        },
        201,
      );
    },
  );
};
