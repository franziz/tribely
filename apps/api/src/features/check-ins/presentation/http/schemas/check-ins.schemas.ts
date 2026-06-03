import { z } from 'zod';

// ---- Bodies ----

/**
 * Request body for POST /me/post-event-check-ins/:id/acknowledge.
 *
 * The acknowledge endpoint takes no meaningful body. This empty schema is
 * mounted via `optionalJsonValidator` so the empty-body tolerance is
 * structural (the construct owns it) rather than implicit (no validator
 * mounted). Extra keys are silently ignored — we must not start 400-ing
 * on stray fields from future mobile clients.
 */
export const acknowledgeCheckInBodySchema = z.object({});

/**
 * Request body for POST /me/post-event-check-ins/:id/flag.
 *
 * The aggregate enforces the empty-after-trim / too-long-after-trim invariants
 * at the domain layer — this schema is the first line of defence (network
 * boundary), not the invariant guardian.
 *
 * `disclaimerAcknowledged` is accepted as any boolean here; the use case
 * enforces `=== true` and returns a named subcode so operators can surface
 * a meaningful error to callers that submit `false`.
 */
export const flagCheckInBodySchema = z.object({
  reportBody: z.string().trim().min(1).max(2000),
  disclaimerAcknowledged: z.boolean(),
});

// ---- Inferred types ----

export type AcknowledgeCheckInBody = z.infer<typeof acknowledgeCheckInBodySchema>;
export type FlagCheckInBody = z.infer<typeof flagCheckInBodySchema>;
