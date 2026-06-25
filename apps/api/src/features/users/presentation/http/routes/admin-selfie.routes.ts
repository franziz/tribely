import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import type { RejectSelfieUseCase } from '../../../application/usecases/reject-selfie.usecase.js';
import type { ApproveSelfieAppealUseCase } from '../../../application/usecases/approve-selfie-appeal.usecase.js';
import type { ApproveSelfieUseCase } from '../../../application/usecases/approve-selfie.usecase.js';
import { rejectSelfieBodySchema } from '../schemas/admin-selfie.schemas.js';

export interface AdminSelfieRouteDeps {
  rejectSelfie: RejectSelfieUseCase;
  approveSelfieAppeal: ApproveSelfieAppealUseCase;
  approveSelfie: ApproveSelfieUseCase;
}

/**
 * Admin routes for selfie moderation (TRI-70, TRI-23).
 *
 * Composed as a sub-router mounted at /users inside the /admin Hono sub-app
 * in app.ts. Final URL paths:
 *
 * POST /admin/users/:id/selfie/reject          — reject a pending selfie
 * POST /admin/users/:id/selfie/approve         — approve a pending selfie (TRI-23 Brief B)
 * POST /admin/users/:id/selfie/appeal/approve  — approve a locked user's appeal
 *
 * Admin enforcement (requireAuth + requireAdmin) is applied at the /admin/*
 * mount point in app.ts — not here. This router contains only the handler logic.
 */
export const buildAdminSelfieRoutes = (deps: AdminSelfieRouteDeps): Hono => {
  return new Hono()
    .post('/:id/selfie/reject', zValidator('json', rejectSelfieBodySchema), async (c) => {
      const userId = c.req.param('id');
      const body = c.req.valid('json');
      await deps.rejectSelfie.execute({
        userId,
        failureCategory: body.failureCategory,
      });
      return c.json({ success: true }, 200);
    })
    .post('/:id/selfie/approve', async (c) => {
      const userId = c.req.param('id');
      await deps.approveSelfie.execute({ userId });
      return c.json({ success: true }, 200);
    })
    .post('/:id/selfie/appeal/approve', async (c) => {
      const userId = c.req.param('id');
      await deps.approveSelfieAppeal.execute({ userId });
      return c.json({ success: true }, 200);
    });
};
