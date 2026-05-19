import { Hono, type Context } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { rateLimit } from '@/core/middleware/rate-limit.js';
import { requireAuth, type AuthVariables } from '@/core/middleware/require-auth.js';
import { requireVerifiedEmail } from '@/core/middleware/require-verified-email.js';
import type { RateLimiter } from '@/core/security/rate-limiter.port.js';
import type { AccessTokenIssuer } from '@/features/auth/domain/ports/access-token-issuer.port.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import type { ReportController } from '../controllers/report.controller.js';
import { fileReportBodySchema } from '../schemas/report.schemas.js';

export interface ReportRouteDeps {
  controller: ReportController;
  accessTokens: AccessTokenIssuer;
  userRepository: UserRepository;
  rateLimiter: RateLimiter;
}

export const buildReportRoutes = (deps: ReportRouteDeps): Hono<{ Variables: AuthVariables }> => {
  const { controller } = deps;
  const auth = requireAuth(deps.accessTokens);
  const verifiedEmail = requireVerifiedEmail(deps.userRepository);

  // 20 reports per hour per user. Per-user key (not per-IP) — meaningful only
  // after authentication.
  const userKey = (c: Context): string =>
    (c as Context<{ Variables: AuthVariables }>).get('userId');
  const limitFileReport = rateLimit(deps.rateLimiter, {
    bucket: 'reports-file',
    limit: 20,
    windowSeconds: 60 * 60,
    keyFor: userKey,
  });

  return new Hono<{ Variables: AuthVariables }>().post(
    '/',
    auth,
    verifiedEmail,
    limitFileReport,
    zValidator('json', fileReportBodySchema),
    (c) => controller.fileAction(c, c.get('userId'), c.req.valid('json')),
  );
};
