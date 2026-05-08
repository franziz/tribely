import { z } from 'zod';

export const signUpBodySchema = z.object({
  email: z.string().email(),
  password: z.string().min(8).max(128),
  displayName: z.string().min(1).max(100),
});

export const signInBodySchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

export const userResponseSchema = z.object({
  id: z.string(),
  email: z.string().email(),
  displayName: z.string(),
  createdAt: z.string(),
  updatedAt: z.string(),
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
