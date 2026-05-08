import { AppError } from '@/core/errors/app-error.js';
import type { User } from '../../domain/entities/user.js';
import type { UserRepository } from '../../domain/repositories/user.repository.js';

export interface GetUserInput {
  id: string;
}

export class GetUserUseCase {
  constructor(private readonly users: UserRepository) {}

  async execute(input: GetUserInput): Promise<User> {
    const user = await this.users.findById(input.id);
    if (!user) throw AppError.notFound(`User ${input.id} not found`);
    return user;
  }
}
