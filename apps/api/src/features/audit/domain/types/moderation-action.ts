/**
 * Closed-set union types describing the moderation action surface.
 *
 * Shared by:
 *   - audit/domain/repositories/moderation-action-audit.repository.ts
 *   - audit/application/usecases/record-moderation-action.usecase.ts
 *   - reports/application/usecases/perform-moderation-action.usecase.ts
 *   - scripts/moderation.ts (CLI)
 *
 * Lives in audit/domain/types/ (not value-objects/) because these are
 * primitive closed-set string unions with no behaviour or invariants,
 * not classes. See A17.
 */
export type ModerationAction = 'touch' | 'resolve_hidden' | 'resolve_kept' | 'cancel_event_for_safety';
export type ModerationTargetType = 'review' | 'user' | 'event';
