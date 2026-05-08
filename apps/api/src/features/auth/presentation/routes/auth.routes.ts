import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import type { Container } from '@/core/di/container.js';
import { AuthController } from '../controllers/auth.controller.js';
import { signInBodySchema, signUpBodySchema } from '../schemas/auth.schemas.js';

export const buildAuthRoutes = (container: Container) => {
  const controller = new AuthController(container);

  return new Hono()
    .post('/sign-up', zValidator('json', signUpBodySchema), (c) =>
      controller.signUp(c, c.req.valid('json')),
    )
    .post('/sign-in', zValidator('json', signInBodySchema), (c) =>
      controller.signIn(c, c.req.valid('json')),
    );
};
