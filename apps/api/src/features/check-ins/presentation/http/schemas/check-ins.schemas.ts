import { z } from 'zod';

// ---- Bodies ----

/**
 * Request body for POST /me/post-event-check-ins/:id/flag.
 *
 * The aggregate enforces the empty-after-trim / too-long-after-trim invariants
 * at the domain layer — this schema is the first line of defence (network
 * boundary), not the invariant guardian.
 */
export const flagCheckInBodySchema = z.object({
  reportBody: z.string().trim().min(1).max(2000),
});

// ---- Inferred types ----

export type FlagCheckInBody = z.infer<typeof flagCheckInBodySchema>;
