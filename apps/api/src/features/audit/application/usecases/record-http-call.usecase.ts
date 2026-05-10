import { createId } from '@paralleldrive/cuid2';
import type {
  HttpAuditLogRecord,
  HttpAuditLogRepository,
} from '../../domain/repositories/http-audit-log.repository.js';

export interface RecordHttpCallInput {
  requestId: string;
  method: string;
  path: string;
  status: number;
  durationMs: number;
  actorUserId: string | null;
  ip: string | null;
  userAgent: string | null;
  errorCode: string | null;
  receivedAt: Date;
}

/**
 * Records one HTTP request → response pair to the audit log. Called by the
 * `audit-http` middleware after the route handler resolves (or after the
 * error-handler has converted an exception to a response).
 *
 * Body content is intentionally NOT in the input — PDPA-friendly. Domain
 * payloads from the request live in `outbox_events.payload` already.
 */
export class RecordHttpCallUseCase {
  constructor(private readonly repository: HttpAuditLogRepository) {}

  async execute(input: RecordHttpCallInput): Promise<void> {
    const record: HttpAuditLogRecord = {
      id: createId(),
      requestId: input.requestId,
      method: input.method,
      path: input.path,
      status: input.status,
      durationMs: input.durationMs,
      actorUserId: input.actorUserId,
      ip: input.ip,
      userAgent: input.userAgent,
      errorCode: input.errorCode,
      receivedAt: input.receivedAt,
    };
    await this.repository.record(record);
  }
}
