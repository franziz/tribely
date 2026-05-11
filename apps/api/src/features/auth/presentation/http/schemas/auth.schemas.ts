import { z } from 'zod';

// ---------------------------------------------------------------------------
// Local user DTO for auth responses.
// This duplicates the shape returned by users/presentation intentionally —
// cross-feature presentation imports are forbidden (A11). The auth feature
// owns this DTO; if the users response shape evolves, update here too.
// ---------------------------------------------------------------------------

const TRAVELER_TYPE_VALUES = ['local', 'traveling', 'expat'] as const;

export const authUserDtoSchema = z.object({
  id: z.string(),
  email: z.string().email(),
  displayName: z.string(),
  emailVerifiedAt: z.string().nullable(),
  bio: z.string().nullable(),
  avatarUrl: z.string().nullable(),
  languages: z.array(z.string()),
  interests: z.array(z.string()),
  currentCity: z.string().nullable(),
  travelerType: z.enum(TRAVELER_TYPE_VALUES).nullable(),
  createdAt: z.string(),
  updatedAt: z.string(),
});

export type AuthUserDto = z.infer<typeof authUserDtoSchema>;

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

export const forgotPasswordBodySchema = z.object({
  email: z.string().email(),
});

export const resetPasswordBodySchema = z.object({
  email: z.string().email(),
  code: z.string().regex(/^\d{6}$/, 'Code must be 6 digits'),
  newPassword: z.string().min(8).max(128),
});

// ---- Responses ----

const issuedTokenSchema = z.object({
  value: z.string(),
  expiresAt: z.string(),
});

export const authResponseSchema = z.object({
  user: authUserDtoSchema,
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
export type ForgotPasswordBody = z.infer<typeof forgotPasswordBodySchema>;
export type ResetPasswordBody = z.infer<typeof resetPasswordBodySchema>;
export type AuthResponse = z.infer<typeof authResponseSchema>;
export type SignOutAllResponse = z.infer<typeof signOutAllResponseSchema>;
