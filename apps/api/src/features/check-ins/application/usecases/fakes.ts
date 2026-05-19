import type { TxContext } from '@/core/db/unit-of-work.port.js';
import { PostEventCheckIn } from '../../domain/entities/post-event-check-in.js';
import type { PostEventCheckInAuditPort } from '../ports/post-event-check-in-audit.port.js';
import type {
  ApprovedAttendanceWithoutCheckIn,
  PostEventCheckInRepository,
  RetentionSweepFilter,
} from '../../domain/repositories/post-event-check-in.repository.js';

// Re-export core-port fakes — their home per the A11 bounded-context rule.
export { FakeEventPublisher, FakeUnitOfWork, FixedClock, TEST_TX } from '@/core/testing/fakes.js';

// Re-export feature-owned fakes from events — avoids cross-feature
// application-layer duplication per CLAUDE.md A11.
export {
  FakeEventRepository,
  FakeUserRepository,
} from '@/features/events/application/usecases/fakes.js';

/**
 * In-memory PostEventCheckInRepository for unit tests.
 *
 * `findApprovedAttendancesWithoutCheckIn` returns from a configurable list
 * seeded via `setAttendances()`. `save` is a upsert keyed by aggregate id.
 */
export class FakePostEventCheckInRepository implements PostEventCheckInRepository {
  private readonly byId = new Map<string, PostEventCheckIn>();
  private _attendances: ApprovedAttendanceWithoutCheckIn[] = [];

  /** Seed pre-existing check-in aggregates (rehydrated — no events). */
  put(checkIn: PostEventCheckIn): void {
    this.byId.set(checkIn.id, checkIn);
  }

  all(): PostEventCheckIn[] {
    return Array.from(this.byId.values());
  }

  /** Seed the attendances that should be returned by findApprovedAttendancesWithoutCheckIn. */
  setAttendances(attendances: ApprovedAttendanceWithoutCheckIn[]): void {
    this._attendances = attendances;
  }

  findById(id: string, ctx?: TxContext): Promise<PostEventCheckIn | null> {
    void ctx;
    return Promise.resolve(this.byId.get(id) ?? null);
  }

  findByUserAndEvent(
    userId: string,
    eventId: string,
    _ctx?: TxContext,
  ): Promise<PostEventCheckIn | null> {
    for (const c of this.byId.values()) {
      if (c.userId === userId && c.eventId === eventId) return Promise.resolve(c);
    }
    return Promise.resolve(null);
  }

  listPendingForUser(userId: string, _ctx?: TxContext): Promise<PostEventCheckIn[]> {
    return Promise.resolve(
      Array.from(this.byId.values()).filter((c) => c.userId === userId && c.status === 'pending'),
    );
  }

  save(checkIn: PostEventCheckIn, _ctx?: TxContext): Promise<void> {
    this.byId.set(checkIn.id, checkIn);
    return Promise.resolve();
  }

  listForRetentionSweep(
    filter: RetentionSweepFilter,
    _ctx?: TxContext,
  ): Promise<PostEventCheckIn[]> {
    return Promise.resolve(
      Array.from(this.byId.values()).filter(
        (c) =>
          c.status === filter.status &&
          c.createdAt.getTime() < filter.olderThan.getTime() &&
          (filter.hasResolvedAt === undefined ||
            (filter.hasResolvedAt ? c.resolvedAt !== null : c.resolvedAt === null)),
      ),
    );
  }

  deleteById(id: string, _ctx: TxContext): Promise<void> {
    this.byId.delete(id);
    return Promise.resolve();
  }

  pseudonymiseForUser(
    input: { userId: string; pseudonymUserId: string; role: 'attendee' | 'host' },
    _ctx: TxContext,
  ): Promise<number> {
    let count = 0;
    for (const checkIn of Array.from(this.byId.values())) {
      if (checkIn.status !== 'flagged') continue;
      if (input.role === 'attendee' && checkIn.userId === input.userId) {
        // Replace with a rehydrated copy carrying the pseudonym in userId.
        this.byId.set(
          checkIn.id,
          PostEventCheckIn.rehydrate({
            id: checkIn.id,
            userId: input.pseudonymUserId,
            eventId: checkIn.eventId,
            hostUserId: checkIn.hostUserId,
            status: checkIn.status,
            createdAt: checkIn.createdAt,
            acknowledgedAt: checkIn.acknowledgedAt,
            flaggedAt: checkIn.flaggedAt,
            reportBody: checkIn.reportBody,
            resolvedAt: checkIn.resolvedAt,
          }),
        );
        count++;
      } else if (input.role === 'host' && checkIn.hostUserId === input.userId) {
        // Replace with a rehydrated copy carrying the pseudonym in hostUserId.
        this.byId.set(
          checkIn.id,
          PostEventCheckIn.rehydrate({
            id: checkIn.id,
            userId: checkIn.userId,
            eventId: checkIn.eventId,
            hostUserId: input.pseudonymUserId,
            status: checkIn.status,
            createdAt: checkIn.createdAt,
            acknowledgedAt: checkIn.acknowledgedAt,
            flaggedAt: checkIn.flaggedAt,
            reportBody: checkIn.reportBody,
            resolvedAt: checkIn.resolvedAt,
          }),
        );
        count++;
      }
    }
    return Promise.resolve(count);
  }

  findApprovedAttendancesWithoutCheckIn(
    _userId: string,
    _window: { sinceEndsAt: Date; untilEndsAt: Date },
    _ctx?: TxContext,
  ): Promise<ApprovedAttendanceWithoutCheckIn[]> {
    return Promise.resolve(this._attendances);
  }
}

type AuditInput = Parameters<PostEventCheckInAuditPort['execute']>[0];

/**
 * Fake PostEventCheckInAuditPort that accumulates calls for assertion.
 */
export class FakeRecordPostEventCheckInEventUseCase implements PostEventCheckInAuditPort {
  readonly calls: Array<{ input: AuditInput; ctx: TxContext }> = [];

  execute(input: AuditInput, ctx: TxContext): Promise<void> {
    this.calls.push({ input, ctx });
    return Promise.resolve();
  }
}
