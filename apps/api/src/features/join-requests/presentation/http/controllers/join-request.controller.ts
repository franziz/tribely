import type { Context } from 'hono';
import type { ApproveJoinRequestUseCase } from '../../../application/usecases/approve-join-request.usecase.js';
import type { CancelJoinRequestByRequesterUseCase } from '../../../application/usecases/cancel-join-request-by-requester.usecase.js';
import type { ListJoinRequestsByEventUseCase } from '../../../application/usecases/list-join-requests-by-event.usecase.js';
import type { RejectJoinRequestUseCase } from '../../../application/usecases/reject-join-request.usecase.js';
import type { RequestToJoinEventUseCase } from '../../../application/usecases/request-to-join-event.usecase.js';
import type { JoinRequest } from '../../../domain/entities/join-request.js';
import type {
  JoinRequestListResponse,
  JoinRequestResponse,
  RejectJoinRequestBody,
} from '../schemas/join-request.schemas.js';

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

export class JoinRequestController {
  constructor(
    private readonly requestToJoinEvent: RequestToJoinEventUseCase,
    private readonly approveJoinRequest: ApproveJoinRequestUseCase,
    private readonly rejectJoinRequest: RejectJoinRequestUseCase,
    private readonly cancelJoinRequestByRequester: CancelJoinRequestByRequesterUseCase,
    private readonly listJoinRequestsByEvent: ListJoinRequestsByEventUseCase,
  ) {}

  createAction = async (c: Context, eventId: string, requesterUserId: string) => {
    const jr = await this.requestToJoinEvent.execute({ eventId, requesterUserId });
    return c.json(toJoinRequestResponse(jr), 201);
  };

  listAction = async (c: Context, eventId: string, actorUserId: string) => {
    const result = await this.listJoinRequestsByEvent.execute({ eventId, actorUserId });
    const response: JoinRequestListResponse = {
      joinRequests: result.joinRequests.map(toJoinRequestResponse),
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
