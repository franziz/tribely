/**
 * Closed-set union types describing the moderation action surface.
 *
 * Shared by:
 *   - audit/domain/repositories/moderation-action-audit.repository.ts
 *   - audit/application/usecases/record-moderation-action.usecase.ts
 *   - reports/domain/entities/report.ts
 *   - reports/application/usecases/escalate-report.usecase.ts
 *   - reports/application/usecases/perform-moderation-action.usecase.ts
 *   - reports/infrastructure/persistence/report.mapper.ts
 *   - scripts/moderation.ts (CLI)
 *
 * Lives in audit/domain/types/ (not value-objects/) because these are
 * primitive closed-set string unions with no behaviour or invariants,
 * not classes. See A17.
 */
export type ModerationAction =
  | 'touch'
  | 'resolve_hidden'
  | 'resolve_kept'
  | 'cancel_event_for_safety'
  | 'escalate'
  | 'record_external_input'
  | 'resolve_with_override';

export type ModerationTargetType = 'review' | 'user' | 'event';

/**
 * Category for escalation actions. Populated when action='escalate' or
 * action='resolve_with_override' (carry-forward for traceability).
 */
export type EscalationCategory =
  | 'criminal-content'
  | 'imminent-harm'
  | 'ambiguous-policy'
  | 'external-jurisdiction';

/**
 * Source of an external input (counsel, regulator, partner).
 * Populated when action='record_external_input'.
 */
export type ExternalInputSource = 'counsel' | 'partner' | 'imda' | 'other';
