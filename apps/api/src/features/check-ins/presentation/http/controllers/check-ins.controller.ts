import type { Context } from 'hono';
import type { AcknowledgeCheckInUseCase } from '../../../application/usecases/acknowledge-check-in.usecase.js';
import type { FlagCheckInUseCase } from '../../../application/usecases/flag-check-in.usecase.js';
import type { SurfacePendingCheckInsUseCase } from '../../../application/usecases/surface-pending-check-ins.usecase.js';
import type { FlagCheckInBody } from '../schemas/check-ins.schemas.js';

export class CheckInsController {
  constructor(
    private readonly surfacePendingCheckIns: SurfacePendingCheckInsUseCase,
    private readonly acknowledgeCheckIn: AcknowledgeCheckInUseCase,
    private readonly flagCheckIn: FlagCheckInUseCase,
  ) {}

  /**
   * GET /me/post-event-check-ins
   *
   * Surfaces pending post-event check-ins for the authenticated attendee.
   * For each event the user attended that ended in the 3h–7d window, ensures
   * a check-in row exists (idempotent) and returns all currently-pending ones
   * enriched with event title, host display name, and event end time.
   */
  listPendingAction = async (c: Context, userId: string) => {
    const result = await this.surfacePendingCheckIns.execute({ userId });
    return c.json(
      {
        items: result.items.map((item) => ({
          id: item.id,
          eventId: item.eventId,
          eventTitle: item.eventTitle,
          hostDisplayName: item.hostDisplayName,
          endedAt: item.endedAt.toISOString(),
          createdAt: item.createdAt.toISOString(),
        })),
      },
      200,
    );
  };

  /**
   * POST /me/post-event-check-ins/:id/acknowledge
   *
   * Attendee acknowledges a pending check-in (transitions pending → ok).
   * No request body — do NOT mount zValidator on this handler.
   */
  acknowledgeAction = async (c: Context, id: string, userId: string) => {
    await this.acknowledgeCheckIn.execute({ id, userId });
    return c.json({ ok: true }, 200);
  };

  /**
   * POST /me/post-event-check-ins/:id/flag
   *
   * Attendee flags a pending check-in with a safety report
   * (transitions pending → flagged).
   */
  flagAction = async (c: Context, id: string, userId: string, body: FlagCheckInBody) => {
    await this.flagCheckIn.execute({ id, userId, reportBody: body.reportBody });
    return c.json({ ok: true }, 200);
  };
}
