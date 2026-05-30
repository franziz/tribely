import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { PostEventCheckIn } from '../entities/post-event-check-in.js';

export interface RetentionSweepFilter {
  status: string;
  olderThan: Date;
  /** When set, restricts to rows where resolvedAt IS NOT NULL (true) or IS NULL (false). */
  hasResolvedAt?: boolean;
}

export interface ApprovedAttendanceWithoutCheckIn {
  eventId: string;
  hostUserId: string;
}

/**
 * Repository for the PostEventCheckIn aggregate.
 */
export interface PostEventCheckInRepository {
  findById(id: string, ctx?: TxContext): Promise<PostEventCheckIn | null>;

  findByUserAndEvent(
    userId: string,
    eventId: string,
    ctx?: TxContext,
  ): Promise<PostEventCheckIn | null>;

  listPendingForUser(userId: string, ctx?: TxContext): Promise<PostEventCheckIn[]>;

  /**
   * Returns all check-ins authored by `userId` with the given non-evidentiary status.
   * Used by the account-deletion cascade to enumerate rows requiring per-row delete + audit.
   */
  listByUserAndStatus(
    userId: string,
    status: 'pending' | 'ok',
    ctx?: TxContext,
  ): Promise<PostEventCheckIn[]>;

  /** Upsert by id. */
  save(checkIn: PostEventCheckIn, ctx: TxContext): Promise<void>;

  /**
   * Single shape for all three sweep query variants:
   *   - status + olderThan (all rows older than cut-off with given status)
   *   - + hasResolvedAt=true (resolved only)
   *   - + hasResolvedAt=false (unresolved only)
   */
  listForRetentionSweep(filter: RetentionSweepFilter, ctx?: TxContext): Promise<PostEventCheckIn[]>;

  deleteById(id: string, ctx: TxContext): Promise<void>;

  /**
   * Pseudonymise all check-ins for a user by replacing userId (role='attendee')
   * or hostUserId (role='host') with a stable pseudonymUserId.
   * Returns the number of rows touched.
   */
  pseudonymiseForUser(
    input: { userId: string; pseudonymUserId: string; role: 'attendee' | 'host' },
    ctx: TxContext,
  ): Promise<number>;

  /**
   * Returns events where the user had an approved join request, the event has
   * already ended (within the look-back window), and no check-in exists yet.
   * Used by the foreground-resume flow to prompt the user.
   *
   * @param userId         The attendee whose approved requests are queried.
   * @param sinceEndsAt    Lower bound on event.endsAt (exclusive) — typically now - 7d.
   * @param untilEndsAt    Upper bound on event.endsAt (exclusive) — typically now - 3h.
   * @param ctx            Optional transaction context.
   */
  findApprovedAttendancesWithoutCheckIn(
    userId: string,
    window: { sinceEndsAt: Date; untilEndsAt: Date },
    ctx?: TxContext,
  ): Promise<ApprovedAttendanceWithoutCheckIn[]>;
}
