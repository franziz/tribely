/**
 * Valid target types for a report.
 *
 * MVP resolver supports 'review' only. 'user' and 'event' are accepted by
 * the domain so future targets need zero migration, but the HTTP schema (Zod)
 * only allows 'review' today; the target resolver returns `not-implemented`
 * for 'user' and 'event'.
 */
export const REPORT_TARGET_TYPES = ['review', 'user', 'event'] as const;

export type ReportTargetType = (typeof REPORT_TARGET_TYPES)[number];

/**
 * Value object holding the polymorphic target of a report.
 *
 * `type` is validated at construction time (must be a known target type).
 * The `id` is the aggregate ID of the reported entity.
 */
export class ReportTarget {
  private constructor(
    public readonly type: ReportTargetType,
    public readonly id: string,
  ) {}

  static create(type: string, id: string): ReportTarget {
    if (!(REPORT_TARGET_TYPES as readonly string[]).includes(type)) {
      throw new Error(
        `Invalid report target type: "${type}". Must be one of: ${REPORT_TARGET_TYPES.join(', ')}`,
      );
    }
    if (!id || id.trim().length === 0) {
      throw new Error('Report target id must not be empty');
    }
    return new ReportTarget(type as ReportTargetType, id);
  }

  equals(other: ReportTarget): boolean {
    return this.type === other.type && this.id === other.id;
  }
}
