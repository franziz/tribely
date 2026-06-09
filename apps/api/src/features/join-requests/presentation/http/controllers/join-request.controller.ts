import type { Context } from 'hono';
import { AppError } from '@/core/errors/app-error.js';
import type { ApproveJoinRequestUseCase } from '../../../application/usecases/approve-join-request.usecase.js';
import type { CancelJoinRequestByRequesterUseCase } from '../../../application/usecases/cancel-join-request-by-requester.usecase.js';
import type { ListJoinRequestsByEventUseCase } from '../../../application/usecases/list-join-requests-by-event.usecase.js';
import type {
  ListJoinRequestsByRequesterInput,
  ListJoinRequestsByRequesterUseCase,
} from '../../../application/usecases/list-join-requests-by-requester.usecase.js';
import type { RejectJoinRequestUseCase } from '../../../application/usecases/reject-join-request.usecase.js';
import type { RemoveJoinRequestByHostUseCase } from '../../../application/usecases/remove-join-request-by-host.usecase.js';
import type { RequestToJoinEventUseCase } from '../../../application/usecases/request-to-join-event.usecase.js';
import type { JoinRequest } from '../../../domain/entities/join-request.js';
import type {
  EnrichedJoinRequestListResponse,
  JoinRequestResponse,
  ListJoinRequestsByEventQuery,
  ListMyJoinRequestsQuery,
  MyJoinRequestsListResponse,
  RejectJoinRequestBody,
  RemoveAttendeeBody,
  RequestToJoinEventBody,
} from '../schemas/join-request.schemas.js';
import type { ListJoinRequestsByRequesterCursor } from '../../../domain/repositories/join-request.repository.js';

const toJoinRequestResponse = (jr: JoinRequest): JoinRequestResponse => ({
  id: jr.id,
  eventId: jr.eventId,
  requesterUserId: jr.requesterUserId,
  status: jr.status,
  requestedAt: jr.requestedAt.toISOString(),
  decidedAt: jr.decidedAt?.toISOString() ?? null,
  decidedByUserId: jr.decidedByUserId,
  decisionReason: jr.decisionReason,
});

/**
 * Encode a keyset cursor as a base64url JSON string. Opaque to the client —
 * callers pass it back verbatim. We mirror the events cursor pattern: no
 * signing needed because `(requestedAt, id)` is harmless to expose.
 */
const encodeCursor = (cursor: ListJoinRequestsByRequesterCursor): string =>
  Buffer.from(
    JSON.stringify({
      lastRequestedAt: cursor.lastRequestedAt.toISOString(),
      lastJoinRequestId: cursor.lastJoinRequestId,
    }),
    'utf8',
  ).toString('base64url');

const decodeCursor = (raw: string): ListJoinRequestsByRequesterCursor => {
  try {
    const decoded: unknown = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8'));
    if (
      typeof decoded !== 'object' ||
      decoded === null ||
      !('lastRequestedAt' in decoded) ||
      !('lastJoinRequestId' in decoded) ||
      typeof (decoded as { lastRequestedAt: unknown }).lastRequestedAt !== 'string' ||
      typeof (decoded as { lastJoinRequestId: unknown }).lastJoinRequestId !== 'string'
    ) {
      throw new Error('shape');
    }
    const { lastRequestedAt, lastJoinRequestId } = decoded as {
      lastRequestedAt: string;
      lastJoinRequestId: string;
    };
    const at = new Date(lastRequestedAt);
    if (Number.isNaN(at.getTime())) throw new Error('date');
    return { lastRequestedAt: at, lastJoinRequestId };
  } catch {
    throw AppError.validation('Invalid cursor');
  }
};

export class JoinRequestController {
  constructor(
    private readonly requestToJoinEvent: RequestToJoinEventUseCase,
    private readonly approveJoinRequest: ApproveJoinRequestUseCase,
    private readonly rejectJoinRequest: RejectJoinRequestUseCase,
    private readonly removeJoinRequestByHost: RemoveJoinRequestByHostUseCase,
    private readonly cancelJoinRequestByRequester: CancelJoinRequestByRequesterUseCase,
    private readonly listJoinRequestsByEvent: ListJoinRequestsByEventUseCase,
    private readonly listJoinRequestsByRequester: ListJoinRequestsByRequesterUseCase,
  ) {}

  /**
   * POST /events/:id/join-requests
   *
   * Body is entirely optional — the mobile Dio client sends Content-Type:
   * application/json with an empty body and must receive 201 (TRI-28 / TRI-34
   * empty-body trap). Tolerant body parsing is handled upstream by
   * `optionalJsonValidator(requestToJoinEventBodySchema)` on the route, which
   * resolves absent/empty/unparseable bodies to `{}` before schema validation.
   * Invalid bodies (e.g. `acknowledgedSafetyReminder: "yes"`) are rejected 400
   * by the middleware before this handler runs.
   */
  createAction = async (
    c: Context,
    eventId: string,
    requesterUserId: string,
    body: RequestToJoinEventBody,
  ) => {
    const jr = await this.requestToJoinEvent.execute({
      eventId,
      requesterUserId,
      ...(body.acknowledgedSafetyReminder !== undefined && {
        acknowledgedSafetyReminder: body.acknowledgedSafetyReminder,
      }),
    });
    return c.json(toJoinRequestResponse(jr), 201);
  };

  /**
   * C2: GET /events/:id/join-requests — returns enriched shape with requester
   * displayName so the host can render a name alongside each row.
   *
   * Accepts an optional `status` query param (repeatable) to filter by status.
   * Defaults to `['pending']` at the use-case layer when absent — preserving
   * the original contract for the pending-requests list.
   */
  listAction = async (
    c: Context,
    eventId: string,
    actorUserId: string,
    query: ListJoinRequestsByEventQuery,
  ) => {
    const result = await this.listJoinRequestsByEvent.execute({
      eventId,
      actorUserId,
      ...(query.status !== undefined && { status: query.status }),
    });
    const response: EnrichedJoinRequestListResponse = {
      joinRequests: result.joinRequests.map((item) => ({
        joinRequest: toJoinRequestResponse(item.joinRequest),
        requester: { id: item.requester.id, displayName: item.requester.displayName.value },
      })),
    };
    return c.json(response, 200);
  };

  /**
   * C1: GET /me/join-requests — requester's own requests with event summary.
   */
  listMineAction = async (c: Context, requesterUserId: string, query: ListMyJoinRequestsQuery) => {
    const input: ListJoinRequestsByRequesterInput = {
      requesterUserId,
      limit: query.limit,
      ...(query.eventId !== undefined && { eventId: query.eventId }),
      ...(query.cursor !== undefined && { cursor: decodeCursor(query.cursor) }),
    };
    const result = await this.listJoinRequestsByRequester.execute(input);
    const response: MyJoinRequestsListResponse = {
      joinRequests: result.items.map((item) => ({
        joinRequest: toJoinRequestResponse(item.joinRequest),
        event: {
          id: item.event.id,
          title: item.event.title,
          startsAt: item.event.startsAt.toISOString(),
          endsAt: item.event.endsAt.toISOString(),
          venue: { address: item.event.venue.address, city: item.event.venue.city },
          status: item.event.status,
          capacity: item.event.capacity.value,
        },
      })),
      nextCursor: result.nextCursor ? encodeCursor(result.nextCursor) : null,
    };
    return c.json(response, 200);
  };

  approveAction = async (c: Context, joinRequestId: string, actorUserId: string) => {
    const jr = await this.approveJoinRequest.execute({ joinRequestId, actorUserId });
    return c.json(toJoinRequestResponse(jr), 200);
  };

  rejectAction = async (
    c: Context,
    joinRequestId: string,
    actorUserId: string,
    body: RejectJoinRequestBody,
  ) => {
    const jr = await this.rejectJoinRequest.execute({
      joinRequestId,
      actorUserId,
      reason: body.reason,
    });
    return c.json(toJoinRequestResponse(jr), 200);
  };

  removeAttendeeAction = async (
    c: Context,
    joinRequestId: string,
    actorUserId: string,
    body: RemoveAttendeeBody,
  ) => {
    const jr = await this.removeJoinRequestByHost.execute({
      joinRequestId,
      actorUserId,
      reason: body.reason,
    });
    return c.json(toJoinRequestResponse(jr), 200);
  };

  cancelAction = async (c: Context, joinRequestId: string, actorUserId: string) => {
    await this.cancelJoinRequestByRequester.execute({ joinRequestId, actorUserId });
    return c.body(null, 204);
  };
}
