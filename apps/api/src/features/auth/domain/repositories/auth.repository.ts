import type { User } from '../entities/user.js';

export interface CreateUserInput {
  email: string;
  passwordHash: string;
  displayName: string;
}

export interface AuthRepository {
  findUserByEmail(email: string): Promise<User | null>;
  findUserById(id: string): Promise<User | null>;
  createUser(input: CreateUserInput): Promise<User>;
  getPasswordHash(userId: string): Promise<string | null>;
}
