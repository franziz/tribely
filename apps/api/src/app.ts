import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger as honoLogger } from 'hono/logger';
import { buildContainer, type Container } from './core/di/container.js';
import { errorHandler } from './core/middleware/error-handler.js';
import { requestContext } from './core/middleware/request-context.js';
import { auditHttp } from './features/audit/presentation/middleware/audit-http.js';
import { buildAuthRoutes } from './features/auth/presentation/http/routes/auth.routes.js';
import { EventController } from './features/events/presentation/http/controllers/event.controller.js';
import { buildEventRoutes } from './features/events/presentation/http/routes/event.routes.js';
import { buildMyEventRoutes } from './features/events/presentation/http/routes/my-event.routes.js';
import { JoinRequestController } from './features/join-requests/presentation/http/controllers/join-request.controller.js';
import { buildEventScopedJoinRequestRoutes } from './features/join-requests/presentation/http/routes/event-scoped-join-request.routes.js';
import { buildJoinRequestRoutes } from './features/join-requests/presentation/http/routes/join-request.routes.js';
import { buildMyJoinRequestsRoutes } from './features/join-requests/presentation/http/routes/my-join-request.routes.js';
import { buildUserRoutes } from './features/users/presentation/http/routes/user.routes.js';
import { buildPendingReviewPromptsRoutes } from './features/users/presentation/http/routes/pending-review-prompts.routes.js';
import { buildAdminSelfieRoutes } from './features/users/presentation/http/routes/admin-selfie.routes.js';
import { requireAuth } from './core/middleware/require-auth.js';
import { requireAdmin } from './core/middleware/require-admin.js';
import { buildCheckInsRoutes } from './features/check-ins/presentation/http/routes/check-ins.routes.js';
import {
  buildEventScopedReviewRoutes,
  buildMyReviewRoutes,
  buildReviewRoutes,
  buildUserScopedReviewRoutes,
} from './features/reviews/presentation/http/routes/review.routes.js';
import { buildReportRoutes } from './features/reports/presentation/http/routes/report.routes.js';
import { buildUserBlockRoutes } from './features/user-blocks/presentation/http/routes/user-block.routes.js';
import { buildSelfieIntakeRoutes } from './features/selfies/presentation/http/routes/selfie-intake.routes.js';
import { buildSupportRoutes } from './features/support/presentation/http/routes/support.routes.js';

export const buildApp = (): { app: Hono; container: Container } => {
  const container = buildContainer();
  const app = new Hono();

  app.use('*', cors());
  // Open the AsyncLocalStorage frame BEFORE any code that might publish
  // domain events. Routes / requireAuth / publisher / dispatcher all read
  // it via getRequestContext().
  app.use('*', requestContext());
  // auditHttp records the request *after* `next()` returns — so it sees
  // the final response status (including statuses set by errorHandler when
  // an exception was thrown). Must be after requestContext.
  app.use('*', auditHttp(container.recordHttpCallUseCase));
  app.use('*', honoLogger());

  app.get('/health', (c) => c.json({ status: 'ok' }));

  app.route(
    '/auth',
    buildAuthRoutes({
      signUp: container.signUpUseCase,
      signIn: container.signInUseCase,
      refresh: container.refreshTokensUseCase,
      signOut: container.signOutUseCase,
      signOutAll: container.signOutAllUseCase,
      getUser: container.getUserUseCase,
      verifyEmail: container.verifyEmailUseCase,
      resendVerification: container.resendEmailVerificationUseCase,
      requestPasswordReset: container.requestPasswordResetUseCase,
      resetPassword: container.resetPasswordUseCase,
      startPhoneVerification: container.startPhoneVerificationUseCase,
      verifyPhone: container.verifyPhoneUseCase,
      accessTokens: container.accessTokens,
      rateLimiter: container.rateLimiter,
    }),
  );
  // TRI-23 Brief A — selfie intake routes (presign + submit), additive under /auth.
  // POST /auth/selfie        — presign a selfie upload URL
  // POST /auth/selfie/submit — record a submitted selfie as pending
  app.route(
    '/auth',
    buildSelfieIntakeRoutes({
      requestSelfieUpload: container.requestSelfieUploadUseCase,
      submitSelfie: container.submitSelfieUseCase,
      accessTokens: container.accessTokens,
      logger: container.logger,
    }),
  );
  app.route(
    '/users',
    buildUserRoutes({
      getUser: container.getUserUseCase,
      updateUserProfile: container.updateUserProfileUseCase,
      getUserCapabilities: container.getUserCapabilitiesUseCase,
      deleteAccount: container.deleteAccountUseCase,
      accessTokens: container.accessTokens,
      clock: container.clock,
      userRepository: container.userRepository,
    }),
  );
  const eventController = new EventController(
    container.createEventUseCase,
    container.listEventsUseCase,
    container.getEventUseCase,
    container.updateEventUseCase,
    container.cancelEventUseCase,
  );
  app.route(
    '/events',
    buildEventRoutes({
      controller: eventController,
      accessTokens: container.accessTokens,
      rateLimiter: container.rateLimiter,
      userRepository: container.userRepository,
    }),
  );
  // GET /me/events — authenticated user's own hosted events.
  // Mirrors the /me/join-requests pattern (MyJoinRequestRoutes).
  app.route(
    '/me',
    buildMyEventRoutes({
      controller: eventController,
      accessTokens: container.accessTokens,
      userRepository: container.userRepository,
    }),
  );

  // Join requests: one controller, three routers, three mount points.
  //   /events/:id/join-requests       — discovering/listing under the parent
  //   /join-requests/:id/{approve,reject} + DELETE — operating on a single row
  //   /me/join-requests               — requester's own join requests
  // Hono's app.route() is additive — multiple mounts at `/events` merge into
  // the parent router's tree. The event router owns `/events`, `/events/:id`;
  // this router owns `/events/:id/join-requests` — non-overlapping paths.
  const joinRequestController = new JoinRequestController(
    container.requestToJoinEventUseCase,
    container.approveJoinRequestUseCase,
    container.rejectJoinRequestUseCase,
    container.removeJoinRequestByHostUseCase,
    container.cancelJoinRequestByRequesterUseCase,
    container.listJoinRequestsByEventUseCase,
    container.listJoinRequestsByRequesterUseCase,
  );
  app.route(
    '/events',
    buildEventScopedJoinRequestRoutes({
      controller: joinRequestController,
      accessTokens: container.accessTokens,
      userRepository: container.userRepository,
      rateLimiter: container.rateLimiter,
    }),
  );
  app.route(
    '/join-requests',
    buildJoinRequestRoutes({
      controller: joinRequestController,
      accessTokens: container.accessTokens,
      userRepository: container.userRepository,
    }),
  );
  app.route(
    '/me',
    buildMyJoinRequestsRoutes({
      controller: joinRequestController,
      accessTokens: container.accessTokens,
      userRepository: container.userRepository,
    }),
  );

  // Reviews: four routers, four mount points.
  //   /events/:eventId/reviews     — POST: submit a review (merged with /events)
  //   /reviews/:reviewId           — PATCH: edit a review
  //   /users/:userId/reviews       — GET: list reviews about a user (merged with /users)
  //   /me/reviews/written          — GET: list reviews written by me (merged with /me)
  // All additive Hono mounts — no existing routes are overridden (CLAUDE.md gotcha).
  const reviewDeps = {
    controller: container.reviewController,
    accessTokens: container.accessTokens,
    userRepository: container.userRepository,
  };
  app.route('/events', buildEventScopedReviewRoutes(reviewDeps));
  app.route('/reviews', buildReviewRoutes(reviewDeps));
  app.route('/users', buildUserScopedReviewRoutes(reviewDeps));
  app.route('/me', buildMyReviewRoutes(reviewDeps));

  // Reports: POST /reports — file a content-moderation report.
  app.route(
    '/reports',
    buildReportRoutes({
      controller: container.reportController,
      accessTokens: container.accessTokens,
      userRepository: container.userRepository,
      rateLimiter: container.rateLimiter,
    }),
  );

  // User blocks: POST/DELETE/GET /me/blocks — additive mount at /me.
  app.route(
    '/me',
    buildUserBlockRoutes({
      controller: container.userBlockController,
      accessTokens: container.accessTokens,
      userRepository: container.userRepository,
      rateLimiter: container.rateLimiter,
    }),
  );

  // GET /me/pending-review-prompts — returns the next unreviewed counterpart
  // for the authenticated user's completed events. Additive mount at /me.
  app.route(
    '/me',
    buildPendingReviewPromptsRoutes({
      listPendingReviewPrompts: container.listPendingReviewPromptsUseCase,
      accessTokens: container.accessTokens,
      userRepository: container.userRepository,
    }),
  );

  // Support: POST /support/tickets — auth-gated, domain-enforced rate limit.
  app.route(
    '/support',
    buildSupportRoutes({
      submitSupportTicket: container.submitSupportTicketUseCase,
      accessTokens: container.accessTokens,
    }),
  );

  // Admin routes — requireAuth + requireAdmin applied once at the /admin/* mount.
  // All sub-routes inherit these guards; no per-route auth boilerplate is needed.
  // Registration order: app.use BEFORE app.route so the middleware is in the
  // matcher before routes attach (Hono middleware registration order rule).
  const auth = requireAuth(container.accessTokens);
  const admin = requireAdmin(container.userRepository);
  app.use('/admin/*', auth, admin);
  const adminRoutes = new Hono().route(
    '/users',
    buildAdminSelfieRoutes({
      rejectSelfie: container.rejectSelfieUseCase,
      approveSelfie: container.approveSelfieUseCase,
      approveSelfieAppeal: container.approveSelfieAppealUseCase,
    }),
  );
  app.route('/admin', adminRoutes);

  // Post-event check-ins (TRI-29). Mounted under /me — no requireVerifiedEmail/Phone
  // guard (check-ins surface on foreground-resume; must not block on verification).
  app.route(
    '/me/post-event-check-ins',
    buildCheckInsRoutes({
      controller: container.checkInsController,
      accessTokens: container.accessTokens,
    }),
  );

  app.onError(errorHandler);
  app.notFound((c) => c.json({ error: { code: 'NOT_FOUND', message: 'Route not found' } }, 404));

  return { app, container };
};

export type AppType = ReturnType<typeof buildApp>['app'];
