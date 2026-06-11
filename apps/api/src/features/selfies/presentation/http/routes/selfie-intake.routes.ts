import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import { requireAuth, type AuthVariables } from '@/core/middleware/require-auth.js';
import { requireSelfieIntakeEnabled } from '@/core/middleware/require-selfie-intake-enabled.js';
import type { AccessTokenIssuer } from '@/features/auth/domain/ports/access-token-issuer.port.js';
import type { Logger } from '@/core/observability/logger.port.js';
import type { RequestSelfieUploadUseCase } from '../../../application/usecases/request-selfie-upload.usecase.js';
import type { SubmitSelfieUseCase } from '../../../application/usecases/submit-selfie.usecase.js';

export interface SelfieIntakeRouteDeps {
  requestSelfieUpload: RequestSelfieUploadUseCase;
  submitSelfie: SubmitSelfieUseCase;
  accessTokens: AccessTokenIssuer;
  logger: Logger;
}

const submitSelfieBodySchema = z.object({
  storageKey: z.string().min(1),
});

/**
 * Selfie intake routes — mounted under `/auth` in `app.ts`.
 *
 * POST /auth/selfie           — presign: returns { uploadUrl, storageKey }.
 *                               No request body (avoids Hono empty-body trap).
 * POST /auth/selfie/submit    — record: { storageKey } → pending selfie row.
 *
 * Both endpoints require:
 *   requireAuth → requireSelfieIntakeEnabled → handler
 *
 * `requireSelfieIntakeEnabled` is a no-op outside production. In production
 * it refuses with 503 SELFIE_INTAKE_DISABLED until SELFIE_DELETION_AUTOMATION_READY=true.
 *
 * Note: the presign endpoint deliberately has NO zValidator('json', ...) —
 * mounting one on a no-body POST triggers the Hono empty-body trap (400 on
 * absent body). See CLAUDE.md gotcha and TRI-28/TRI-34 precedent.
 */
export const buildSelfieIntakeRoutes = (
  deps: SelfieIntakeRouteDeps,
): Hono<{ Variables: AuthVariables }> => {
  const auth = requireAuth(deps.accessTokens);
  const intakeEnabled = requireSelfieIntakeEnabled(deps.logger);

  return new Hono<{ Variables: AuthVariables }>()
    .post('/selfie', auth, intakeEnabled, async (c) => {
      const result = await deps.requestSelfieUpload.execute({
        userId: c.get('userId'),
      });
      return c.json(result, 200);
    })
    .post(
      '/selfie/submit',
      auth,
      intakeEnabled,
      zValidator('json', submitSelfieBodySchema),
      async (c) => {
        await deps.submitSelfie.execute({
          userId: c.get('userId'),
          storageKey: c.req.valid('json').storageKey,
        });
        return c.json({ success: true }, 200);
      },
    );
};
