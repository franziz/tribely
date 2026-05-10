import { Hono, type Context } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { rateLimit } from '@/core/middleware/rate-limit.js';
import { requireAuth, type AuthVariables } from '@/core/middleware/require-auth.js';
import type { RateLimiter } from '@/core/security/rate-limiter.port.js';
import type { GetUserUseCase } from '@/features/users/application/usecases/get-user.usecase.js';
import type { RefreshTokensUseCase } from '../../../application/usecases/refresh-tokens.usecase.js';
import type { ResendEmailVerificationUseCase } from '../../../application/usecases/resend-email-verification.usecase.js';
import type { SignInUseCase } from '../../../application/usecases/sign-in.usecase.js';
import type { SignOutAllUseCase } from '../../../application/usecases/sign-out-all.usecase.js';
import type { SignOutUseCase } from '../../../application/usecases/sign-out.usecase.js';
import type { SignUpUseCase } from '../../../application/usecases/sign-up.usecase.js';
import type { VerifyEmailUseCase } from '../../../application/usecases/verify-email.usecase.js';
import type { AccessTokenIssuer } from '../../../domain/ports/access-token-issuer.port.js';
import { AuthController } from '../controllers/auth.controller.js';
import {
  refreshBodySchema,
  signInBodySchema,
  signOutBodySchema,
  signUpBodySchema,
  verifyEmailBodySchema,
} from '../schemas/auth.schemas.js';

export interface AuthRouteDeps {
  signUp: SignUpUseCase;
  signIn: SignInUseCase;
  refresh: RefreshTokensUseCase;
  signOut: SignOutUseCase;
  signOutAll: SignOutAllUseCase;
  getUser: GetUserUseCase;
  verifyEmail: VerifyEmailUseCase;
  resendVerification: ResendEmailVerificationUseCase;
  accessTokens: AccessTokenIssuer;
  rateLimiter: RateLimiter;
}

export const buildAuthRoutes = (deps: AuthRouteDeps): Hono<{ Variables: AuthVariables }> => {
  const controller = new AuthController(
    deps.signUp,
    deps.signIn,
    deps.refresh,
    deps.signOut,
    deps.signOutAll,
    deps.getUser,
    deps.verifyEmail,
    deps.resendVerification,
  );
  const auth = requireAuth(deps.accessTokens);

  // Rate-limit configurations:
  //   sign-up: 5/min per IP — most users hit it once, abuse is signup-spam.
  //   sign-in: 10/min per IP — legit users retry on typos.
  //   refresh: 30/min per IP — legit clients may refresh frequently with short access TTL.
  //   verify-email: 10/min per user — accommodates fat-finger retries; hard cap
  //     against unauthenticated brute-force is the per-token attempts counter.
  //   resend-verification: 1/min per user — defeats email-bomb / floor-spam. Per-user
  //     because hostile actor on shared NAT shouldn't deny the rest of the office.
  //   sign-out / sign-out-all / me: no global rate limit (auth-required, low risk).
  const limitSignUp = rateLimit(deps.rateLimiter, {
    bucket: 'sign-up',
    limit: 5,
    windowSeconds: 60,
  });
  const limitSignIn = rateLimit(deps.rateLimiter, {
    bucket: 'sign-in',
    limit: 10,
    windowSeconds: 60,
  });
  const limitRefresh = rateLimit(deps.rateLimiter, {
    bucket: 'refresh',
    limit: 30,
    windowSeconds: 60,
  });
  // `keyFor` runs after `requireAuth` populates `userId` in the variables.
  // Casting the Context lets us read it without a `string` assertion.
  const userKey = (c: Context): string =>
    (c as Context<{ Variables: AuthVariables }>).get('userId');
  const limitVerifyEmail = rateLimit(deps.rateLimiter, {
    bucket: 'verify-email',
    limit: 10,
    windowSeconds: 60,
    keyFor: userKey,
  });
  const limitResendVerification = rateLimit(deps.rateLimiter, {
    bucket: 'resend-verification',
    limit: 1,
    windowSeconds: 60,
    keyFor: userKey,
  });

  return new Hono<{ Variables: AuthVariables }>()
    .post('/sign-up', limitSignUp, zValidator('json', signUpBodySchema), (c) =>
      controller.signUpAction(c, c.req.valid('json')),
    )
    .post('/sign-in', limitSignIn, zValidator('json', signInBodySchema), (c) =>
      controller.signInAction(c, c.req.valid('json')),
    )
    .post('/refresh', limitRefresh, zValidator('json', refreshBodySchema), (c) =>
      controller.refreshAction(c, c.req.valid('json')),
    )
    .post('/sign-out', zValidator('json', signOutBodySchema), (c) =>
      controller.signOutAction(c, c.req.valid('json')),
    )
    .post('/sign-out-all', auth, (c) => controller.signOutAllAction(c, c.get('userId')))
    .get('/me', auth, (c) => controller.meAction(c, c.get('userId')))
    .post(
      '/verify-email',
      auth,
      limitVerifyEmail,
      zValidator('json', verifyEmailBodySchema),
      (c) => controller.verifyEmailAction(c, c.get('userId'), c.req.valid('json')),
    )
    .post('/resend-verification', auth, limitResendVerification, (c) =>
      controller.resendVerificationAction(c, c.get('userId')),
    );
};
