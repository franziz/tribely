import { z } from 'zod';
import { userResponseSchema } from '@/features/users/presentation/http/schemas/user.schemas.js';

export const signUpBodySchema = z.object({
  email: z.string().email(),
  password: z.string().min(8).max(128),
  displayName: z.string().min(2).max(50),
});

export const signInBodySchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

export const authResponseSchema = z.object({
  user: userResponseSchema,
  tokens: z.object({
    accessToken: z.string(),
    refreshToken: z.string(),
    accessTokenExpiresAt: z.string(),
  }),
});

export type SignUpBody = z.infer<typeof signUpBodySchema>;
export type SignInBody = z.infer<typeof signInBodySchema>;
export type AuthResponse = z.infer<typeof authResponseSchema>;
