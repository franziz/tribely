import { z } from 'zod';
import type { SelfieFailureCategory } from '../../../domain/value-objects/selfie-failure-category.js';
import { SELFIE_FAILURE_CATEGORIES } from '../../../domain/value-objects/selfie-failure-category.js';

export const rejectSelfieBodySchema = z.object({
  failureCategory: z.enum([...SELFIE_FAILURE_CATEGORIES] as [
    SelfieFailureCategory,
    ...SelfieFailureCategory[],
  ]),
});

export type RejectSelfieBody = z.infer<typeof rejectSelfieBodySchema>;
