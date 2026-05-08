import argon2 from 'argon2';
import { AppError } from '@/core/errors/app-error.js';
import type { User } from '../entities/user.js';
import type { AuthRepository } from '../repositories/auth.repository.js';
import type { AuthTokens, TokenService } from '../services/token.service.js';

export interface SignUpInput {
  email: string;
  password: string;
  displayName: string;
}

export interface SignUpResult {
  user: User;
  tokens: AuthTokens;
}

export class SignUpUseCase {
  constructor(
    private readonly authRepository: AuthRepository,
    private readonly tokenService: TokenService,
  ) {}

  async execute(input: SignUpInput): Promise<SignUpResult> {
    const existing = await this.authRepository.findUserByEmail(input.email);
    if (existing) {
      throw AppError.conflict('Email already registered');
    }

    const passwordHash = await argon2.hash(input.password);

    const user = await this.authRepository.createUser({
      email: input.email,
      passwordHash,
      displayName: input.displayName,
    });

    const tokens = await this.tokenService.issueTokens({ sub: user.id, email: user.email });

    return { user, tokens };
  }
}
