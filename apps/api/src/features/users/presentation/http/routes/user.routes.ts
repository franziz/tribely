import { Hono } from 'hono';
import type { GetUserUseCase } from '../../../application/usecases/get-user.usecase.js';
import { UserController } from '../controllers/user.controller.js';

export const buildUserRoutes = (deps: { getUser: GetUserUseCase }): Hono => {
  const controller = new UserController(deps.getUser);
  return new Hono().get('/:id', (c) => controller.get(c, c.req.param('id')));
};
