import { z } from 'zod';
import { Language } from '../../../domain/value-objects/language.js';
import { Interest } from '../../../domain/value-objects/interest.js';

// ---------------------------------------------------------------------------
// Shared picklist schemas (derive valid values from the VO at schema-build time
// so the HTTP layer and domain layer are always in sync).
// ---------------------------------------------------------------------------

const LANGUAGE_CODES = [...Language.VALID_CODES] as [string, ...string[]];
const INTEREST_CODES = [...Interest.VALID_CODES] as [string, ...string[]];

const TRAVELER_TYPE_VALUES = ['local', 'traveling', 'expat'] as const;

// ---------------------------------------------------------------------------
// Response schema (GET /users/:id + PATCH /users/me response body)
// ---------------------------------------------------------------------------

export const userResponseSchema = z.object({
  id: z.string(),
  email: z.string().email(),
  displayName: z.string(),
  emailVerifiedAt: z.string().nullable(),
  bio: z.string().nullable(),
  avatarUrl: z.string().nullable(),
  languages: z.array(z.enum(LANGUAGE_CODES)),
  interests: z.array(z.enum(INTEREST_CODES)),
  currentCity: z.string().nullable(),
  travelerType: z.enum(TRAVELER_TYPE_VALUES).nullable(),
  createdAt: z.string(),
  updatedAt: z.string(),
});

export type UserResponse = z.infer<typeof userResponseSchema>;

// ---------------------------------------------------------------------------
// PATCH /users/me — all fields optional, patch semantics
// ---------------------------------------------------------------------------

export const updateUserProfileSchema = z.object({
  bio: z.string().trim().min(1).max(300).nullable().optional(),
  avatarUrl: z
    .string()
    .trim()
    .url()
    .max(2048)
    .refine((u) => u.startsWith('https://'), { message: 'Avatar URL must use HTTPS' })
    .nullable()
    .optional(),
  languages: z.array(z.enum(LANGUAGE_CODES)).optional(),
  interests: z.array(z.enum(INTEREST_CODES)).optional(),
  currentCity: z.string().trim().min(1).max(80).nullable().optional(),
  travelerType: z.enum(TRAVELER_TYPE_VALUES).nullable().optional(),
});

export type UpdateUserProfileBody = z.infer<typeof updateUserProfileSchema>;
