import { z } from 'zod';
import { REPORT_REASON_VALUES } from '../../../domain/value-objects/report-reason.js';

// ---- Request bodies ----

/**
 * POST /reports — file a new report.
 *
 * MVP schema only allows `targetType: 'review'`. The domain enum supports
 * 'user' and 'event' too, but those target types are not yet implemented
 * (resolver returns not-implemented, and the schema already rejects them
 * with a 400 here before the use case is called).
 */
export const fileReportBodySchema = z.object({
  targetType: z.literal('review'),
  targetId: z.string().min(1).max(100),
  reason: z.enum(REPORT_REASON_VALUES),
  comment: z.string().max(500).optional(),
});

// ---- Response shapes ----

export const fileReportResponseSchema = z.object({
  report: z.object({
    id: z.string(),
    targetType: z.string(),
    targetId: z.string(),
    reason: z.string(),
    createdAt: z.string(),
  }),
});

// ---- Inferred types ----

export type FileReportBody = z.infer<typeof fileReportBodySchema>;
export type FileReportResponse = z.infer<typeof fileReportResponseSchema>;
