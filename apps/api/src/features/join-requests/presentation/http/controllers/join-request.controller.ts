import type { Context } from 'hono';
import type { ApproveJoinRequestUseCase } from '../../../application/usecases/approve-join-request.usecase.js';
import type { CancelJoinRequestByRequesterUseCase } from '../../../application/usecases/cancel-join-request-by-requester.usecase.js';
import type { ListJoinRequestsByEventUseCase } from '../../../application/usecases/list-join-requests-by-event.usecase.js';
import type {
  ListJoinRequestsByRequesterInput,
  ListJoinRequestsByRequesterUseCase,
} from '../../../application/usecases/list-join-requests-by-requester.usecase.js';
import type { RejectJoinRequestUseCase } from '../../../application/usecases/reject-join-request.usecase.js';
import type { RequestToJoinEventUseCase } from '../../../application/usecases/request-to-join-event.usecase.js';
import type { JoinRequest } from '../../../domain/entities/join-request.js';
import { AppError } from '@/core/errors/app-error.js';
import type {
  EnrichedJoinRequestListResponse,
  JoinRequestResponse,
  ListMyJoinRequestsQuery,
  MyJoinRequestsListResponse,
  RejectJoinRequestBody,
} from '../schemas/join-request.schemas.js';
import type { ListJoinRequestsByRequesterCursor } from '../../../application/dto/list-join-requests-by-requester.result.js';

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
    private readonly cancelJoinRequestByRequester: CancelJoinRequestByRequesterUseCase,
    private readonly listJoinRequestsByEvent: ListJoinRequestsByEventUseCase,
    private readonly listJoinRequestsByRequester: ListJoinRequestsByRequesterUseCase,
  ) {}

  createAction = async (c: Context, eventId: string, requesterUserId: string) => {
    const jr = await this.requestToJoinEvent.execute({ eventId, requesterUserId });
    return c.json(toJoinRequestResponse(jr), 201);
  };

  /**
   * C2: GET /events/:id/join-requests — now returns enriched shape with
   * requester displayName so the host can render a name alongside each row.
   */
  listAction = async (c: Context, eventId: string, actorUserId: string) => {
    const result = await this.listJoinRequestsByEvent.execute({ eventId, actorUserId });
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

  cancelAction = async (c: Context, joinRequestId: string, actorUserId: string) => {
    await this.cancelJoinRequestByRequester.execute({ joinRequestId, actorUserId });
    return c.body(null, 204);
  };
}
