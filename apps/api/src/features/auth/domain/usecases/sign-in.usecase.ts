import argon2 from 'argon2';
import { AppError } from '@/core/errors/app-error.js';
import type { User } from '../entities/user.js';
import type { AuthRepository } from '../repositories/auth.repository.js';
import type { AuthTokens, TokenService } from '../services/token.service.js';

export interface SignInInput {
  email: string;
  password: string;
}

export interface SignInResult {
  user: User;
  tokens: AuthTokens;
}

export class SignInUseCase {
  constructor(
    private readonly authRepository: AuthRepository,
    private readonly tokenService: TokenService,
  ) {}

  async execute(input: SignInInput): Promise<SignInResult> {
    const user = await this.authRepository.findUserByEmail(input.email);
    if (!user) {
      throw AppError.unauthorized('Invalid credentials');
    }

    const hash = await this.authRepository.getPasswordHash(user.id);
    if (!hash) {
      throw AppError.unauthorized('Invalid credentials');
    }

    const isValid = await argon2.verify(hash, input.password);
    if (!isValid) {
      throw AppError.unauthorized('Invalid credentials');
    }

    const tokens = await this.tokenService.issueTokens({ sub: user.id, email: user.email });

    return { user, tokens };
  }
}
