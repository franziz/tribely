import type { Db } from '@/core/db/prisma.js';
import type { UserModel } from '../models/user.model.js';

export interface CreateUserDbInput {
  email: string;
  passwordHash: string;
  displayName: string;
}

export interface AuthDatasource {
  findByEmail(email: string): Promise<UserModel | null>;
  findById(id: string): Promise<UserModel | null>;
  create(input: CreateUserDbInput): Promise<UserModel>;
  getPasswordHash(userId: string): Promise<string | null>;
}

export class AuthDatasourcePrisma implements AuthDatasource {
  constructor(private readonly db: Db) {}

  findByEmail(email: string): Promise<UserModel | null> {
    return this.db.user.findUnique({ where: { email } });
  }

  findById(id: string): Promise<UserModel | null> {
    return this.db.user.findUnique({ where: { id } });
  }

  create(input: CreateUserDbInput): Promise<UserModel> {
    return this.db.user.create({ data: input });
  }

  async getPasswordHash(userId: string): Promise<string | null> {
    const row = await this.db.user.findUnique({
      where: { id: userId },
      select: { passwordHash: true },
    });
    return row?.passwordHash ?? null;
  }
}
