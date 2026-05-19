import { z } from 'zod';
import { SELFIE_FAILURE_CATEGORIES } from '../../../domain/value-objects/selfie-failure-category.js';

export const rejectSelfieBodySchema = z.object({
  failureCategory: z.enum(SELFIE_FAILURE_CATEGORIES as [string, ...string[]]),
});

export type RejectSelfieBody = z.infer<typeof rejectSelfieBodySchema>;
