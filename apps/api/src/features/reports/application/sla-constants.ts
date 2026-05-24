/**
 * Moderation SLA thresholds — hours-since-report-creation cutoffs that
 * drive the CLI's banner output AND the audit/policy layer's overdue
 * classification.
 *
 * Hardcoded here as the SHARED source of truth for the CLI stop-gap
 * (TRI-141). Promotion to env/config is tracked by TRI-156; when that
 * lands, these constants read from `env.MODERATION_SLA_*` and both
 * consumers (this file's importers) keep working unchanged.
 *
 * DO NOT mirror these values elsewhere. Import from this file.
 */
export const SLA_FIRST_TOUCH_HOURS = 72;
export const SLA_HARD_CEILING_HOURS = 168; // 7 days
export const APPROACHING_FIRST_TOUCH_HOURS = 48; // 24h warning window before 72h
export const APPROACHING_HARD_CEILING_HOURS = 120; // 48h warning window before 7d
