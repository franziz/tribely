import { prisma, type Db } from '../db/prisma.js';
import { JwtTokenService } from '@/features/auth/data/services/jwt-token.service.js';
import { AuthDatasourcePrisma } from '@/features/auth/data/datasources/auth.datasource.js';
import { AuthRepositoryImpl } from '@/features/auth/data/repositories/auth.repository.impl.js';
import { SignUpUseCase } from '@/features/auth/domain/usecases/sign-up.usecase.js';
import { SignInUseCase } from '@/features/auth/domain/usecases/sign-in.usecase.js';
import type { AuthRepository } from '@/features/auth/domain/repositories/auth.repository.js';
import type { TokenService } from '@/features/auth/domain/services/token.service.js';

export interface Container {
  db: Db;
  tokenService: TokenService;
  authRepository: AuthRepository;
  signUpUseCase: SignUpUseCase;
  signInUseCase: SignInUseCase;
}

export const buildContainer = (): Container => {
  const db = prisma;
  const tokenService = new JwtTokenService();
  const authDatasource = new AuthDatasourcePrisma(db);
  const authRepository = new AuthRepositoryImpl(authDatasource);

  return {
    db,
    tokenService,
    authRepository,
    signUpUseCase: new SignUpUseCase(authRepository, tokenService),
    signInUseCase: new SignInUseCase(authRepository, tokenService),
  };
};
