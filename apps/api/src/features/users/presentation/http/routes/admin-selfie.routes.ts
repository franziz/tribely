import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
// TODO(TRI-70 follow-up): replace with a real admin-role middleware once the
// admin identity model is designed and implemented. Until then, these endpoints
// are unauthenticated at the middleware level — they MUST be network-restricted
// (private subnet / VPN / internal load balancer) before production use.
// Flag this to the orchestrator/engineering-lead for an explicit admin-auth
// ticket before the Singapore launch.
import type { RejectSelfieUseCase } from '../../../application/usecases/reject-selfie.usecase.js';
import type { ApproveSelfieAppealUseCase } from '../../../application/usecases/approve-selfie-appeal.usecase.js';
import { rejectSelfieBodySchema } from '../schemas/admin-selfie.schemas.js';
import type { SelfieFailureCategory } from '../../../domain/value-objects/selfie-failure-category.js';

export interface AdminSelfieRouteDeps {
  rejectSelfie: RejectSelfieUseCase;
  approveSelfieAppeal: ApproveSelfieAppealUseCase;
}

/**
 * Admin routes for selfie moderation (TRI-70).
 *
 * Mounted at /admin/users/:id/selfie/* in app.ts.
 *
 * POST /admin/users/:id/selfie/reject          — reject a pending selfie
 * POST /admin/users/:id/selfie/appeal/approve  — approve a locked user's appeal
 *
 * SECURITY NOTE: No admin-role middleware is in place yet — see the TODO above.
 * These routes must NOT be publicly reachable without network-level protection
 * until an admin-auth ticket lands.
 */
export const buildAdminSelfieRoutes = (deps: AdminSelfieRouteDeps): Hono => {
  return new Hono()
    .post('/:id/selfie/reject', zValidator('json', rejectSelfieBodySchema), async (c) => {
      const userId = c.req.param('id');
      const body = c.req.valid('json');
      await deps.rejectSelfie.execute({
        userId,
        failureCategory: body.failureCategory as SelfieFailureCategory,
      });
      return c.json({ success: true }, 200);
    })
    .post('/:id/selfie/appeal/approve', async (c) => {
      const userId = c.req.param('id');
      await deps.approveSelfieAppeal.execute({ userId });
      return c.json({ success: true }, 200);
    });
};
