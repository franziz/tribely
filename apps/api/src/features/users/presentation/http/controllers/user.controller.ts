import type { Context } from 'hono';
import type { User } from '../../../domain/entities/user.js';
import type { GetUserUseCase } from '../../../application/usecases/get-user.usecase.js';
import type { UserResponse } from '../schemas/user.schemas.js';

const toResponse = (user: User): UserResponse => ({
  id: user.id,
  email: user.email.value,
  displayName: user.displayName.value,
  emailVerifiedAt: user.emailVerifiedAt?.toISOString() ?? null,
  createdAt: user.createdAt.toISOString(),
  updatedAt: user.updatedAt.toISOString(),
});

export class UserController {
  constructor(private readonly getUser: GetUserUseCase) {}

  get = async (c: Context, id: string) => {
    const user = await this.getUser.execute({ id });
    return c.json(toResponse(user), 200);
  };
}
