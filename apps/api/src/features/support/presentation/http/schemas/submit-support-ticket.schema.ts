import { z } from 'zod';
import { SUPPORT_CATEGORIES } from '../../../domain/value-objects/support-category.js';

// ---- Request body ----

/**
 * POST /support/tickets — submit a support ticket.
 *
 * `category` must be one of the 6 canonical support categories.
 * `message` is trimmed; length enforced 1..4000 after trimming.
 * `reportId` is an optional free-text deep-link reference (not a FK).
 */
export const submitSupportTicketBodySchema = z.object({
  category: z.enum(SUPPORT_CATEGORIES),
  message: z.string().trim().min(1).max(4000),
  reportId: z.string().min(1).max(64).optional(),
});

// ---- Response shape ----

export const submitSupportTicketResponseSchema = z.object({
  ticket: z.object({
    id: z.string(),
    createdAt: z.string(),
  }),
});

// ---- Inferred types ----

export type SubmitSupportTicketBody = z.infer<typeof submitSupportTicketBodySchema>;
export type SubmitSupportTicketResponse = z.infer<typeof submitSupportTicketResponseSchema>;
