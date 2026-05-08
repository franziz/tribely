import type { User } from '../../domain/entities/user.js';
import type {
  AuthRepository,
  CreateUserInput,
} from '../../domain/repositories/auth.repository.js';
import type { AuthDatasource } from '../datasources/auth.datasource.js';
import { toUserEntity } from '../models/user.model.js';

export class AuthRepositoryImpl implements AuthRepository {
  constructor(private readonly datasource: AuthDatasource) {}

  async findUserByEmail(email: string): Promise<User | null> {
    const model = await this.datasource.findByEmail(email);
    return model ? toUserEntity(model) : null;
  }

  async findUserById(id: string): Promise<User | null> {
    const model = await this.datasource.findById(id);
    return model ? toUserEntity(model) : null;
  }

  async createUser(input: CreateUserInput): Promise<User> {
    const model = await this.datasource.create(input);
    return toUserEntity(model);
  }

  getPasswordHash(userId: string): Promise<string | null> {
    return this.datasource.getPasswordHash(userId);
  }
}
