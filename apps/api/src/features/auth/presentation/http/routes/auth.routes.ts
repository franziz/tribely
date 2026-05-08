import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import type { SignInUseCase } from '../../../application/usecases/sign-in.usecase.js';
import type { SignUpUseCase } from '../../../application/usecases/sign-up.usecase.js';
import { AuthController } from '../controllers/auth.controller.js';
import { signInBodySchema, signUpBodySchema } from '../schemas/auth.schemas.js';

export const buildAuthRoutes = (deps: {
  signUp: SignUpUseCase;
  signIn: SignInUseCase;
}): Hono => {
  const controller = new AuthController(deps.signUp, deps.signIn);

  return new Hono()
    .post('/sign-up', zValidator('json', signUpBodySchema), (c) =>
      controller.signUpAction(c, c.req.valid('json')),
    )
    .post('/sign-in', zValidator('json', signInBodySchema), (c) =>
      controller.signInAction(c, c.req.valid('json')),
    );
};
