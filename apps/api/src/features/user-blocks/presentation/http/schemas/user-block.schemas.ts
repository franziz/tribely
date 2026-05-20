import { z } from 'zod';

// ---- Request bodies ----

export const blockUserBodySchema = z.object({
  blockedUserId: z.string().min(1).max(100),
});

// ---- Query params ----

export const listMyBlocksQuerySchema = z.object({
  cursor: z.string().min(1).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

// ---- Inferred types ----

export type BlockUserBody = z.infer<typeof blockUserBodySchema>;
export type ListMyBlocksQuery = z.infer<typeof listMyBlocksQuerySchema>;
