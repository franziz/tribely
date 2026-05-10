import { z } from 'zod';
import { userResponseSchema } from '@/features/users/presentation/http/schemas/user.schemas.js';

// ---- Bodies ----

export const signUpBodySchema = z.object({
  email: z.string().email(),
  password: z.string().min(8).max(128),
  displayName: z.string().min(2).max(50),
  deviceLabel: z.string().max(120).optional(),
});

export const signInBodySchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
  deviceLabel: z.string().max(120).optional(),
});

export const refreshBodySchema = z.object({
  refreshToken: z.string().min(1),
  deviceLabel: z.string().max(120).optional(),
});

export const signOutBodySchema = z.object({
  refreshToken: z.string().min(1),
});

export const verifyEmailBodySchema = z.object({
  // 6-digit numeric, zero-padded. Mobile clients pre-validate but we still
  // enforce server-side so curl users get a clean 400 instead of a generic
  // mismatch.
  code: z.string().regex(/^\d{6}$/, 'Code must be 6 digits'),
});

// ---- Responses ----

const issuedTokenSchema = z.object({
  value: z.string(),
  expiresAt: z.string(),
});

export const authResponseSchema = z.object({
  user: userResponseSchema,
  accessToken: issuedTokenSchema,
  refreshToken: issuedTokenSchema,
});

export const signOutAllResponseSchema = z.object({
  revokedCount: z.number().int().nonnegative(),
});

// ---- Inferred types ----

export type SignUpBody = z.infer<typeof signUpBodySchema>;
export type SignInBody = z.infer<typeof signInBodySchema>;
export type RefreshBody = z.infer<typeof refreshBodySchema>;
export type SignOutBody = z.infer<typeof signOutBodySchema>;
export type VerifyEmailBody = z.infer<typeof verifyEmailBodySchema>;
export type AuthResponse = z.infer<typeof authResponseSchema>;
export type SignOutAllResponse = z.infer<typeof signOutAllResponseSchema>;
