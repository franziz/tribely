import { z } from 'zod';

export const userResponseSchema = z.object({
  id: z.string(),
  email: z.string().email(),
  displayName: z.string(),
  emailVerifiedAt: z.string().nullable(),
  createdAt: z.string(),
  updatedAt: z.string(),
});

export type UserResponse = z.infer<typeof userResponseSchema>;
