import { AppError } from '@/core/errors/app-error.js';
import { sha256Hex } from '@/core/crypto/sha256-hex.js';
import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { EventPublisher } from '@/core/events/event-publisher.port.js';
import type { SupportTicketRepository } from '../../domain/repositories/support-ticket.repository.js';
import type { UserRepository } from '@/features/users/domain/repositories/user.repository.js';
import type {
  SubmitSupportTicketInput,
  SubmitSupportTicketResult,
} from '../dto/support-ticket.dto.js';
import { SupportTicket } from '../../domain/entities/support-ticket.js';
import { SupportCategory } from '../../domain/value-objects/support-category.js';
import { SupportMessage } from '../../domain/value-objects/support-message.js';
import { ReportIdReference } from '../../domain/value-objects/report-id-reference.js';
import { createId } from '@paralleldrive/cuid2';

const RATE_LIMIT_MAX = 5;
const RATE_LIMIT_WINDOW_MS = 24 * 60 * 60 * 1000; // 24 hours

/**
 * Submit a support ticket on behalf of an authenticated user.
 *
 * Enforces a rate limit of 5 tickets per user per 24-hour window.
 * Snapshots the user's email at submission time (pseudonymisation-friendly:
 * the snapshot persists independently if the user later tombstones their account).
 *
 * SHA-256 hashing of the email is done here (application layer) and passed into
 * the aggregate as `userEmailHash` — keeps `node:crypto` out of the domain.
 * The emitted `support.ticketSubmitted` event carries only the hash, not the
 * plaintext email (TRI-16 hash-PII-in-long-lived-events convention).
 */
export class SubmitSupportTicketUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly supportTicketRepository: SupportTicketRepository,
    private readonly userRepository: UserRepository,
    private readonly events: EventPublisher,
  ) {}

  async execute(input: SubmitSupportTicketInput): Promise<SubmitSupportTicketResult> {
    // 1. Validate VOs up-front — throw before any I/O on invalid input.
    const category = SupportCategory.create(input.category);
    const message = SupportMessage.create(input.message);
    const reportIdRef =
      input.reportId !== undefined ? ReportIdReference.create(input.reportId) : undefined;

    // 2. Load user to snapshot email. User.email is always present (non-nullable VO).
    const user = await this.userRepository.findById(input.userId);
    if (user === null) {
      throw AppError.unprocessable('support.userEmailMissing');
    }

    // 3. Enforce rate limit: max 5 tickets per 24h window.
    const since = new Date(Date.now() - RATE_LIMIT_WINDOW_MS);
    const recentCount = await this.supportTicketRepository.countRecentByUser(input.userId, since);
    if (recentCount >= RATE_LIMIT_MAX) {
      throw AppError.unprocessable('support.rateLimited');
    }

    // 4. Hash email here (application layer) so the domain stays free of node:crypto.
    const userEmailHash = sha256Hex(user.email.value.trim().toLowerCase());

    // 5. Construct aggregate — records support.ticketSubmitted with pre-computed hash.
    const now = new Date();
    const ticket = SupportTicket.create({
      id: createId(),
      userId: input.userId,
      userEmailSnapshot: user.email.value,
      userEmailHash,
      category,
      message,
      ...(reportIdRef !== undefined ? { reportId: reportIdRef } : {}),
      now,
    });

    // 6. Persist + publish events atomically inside a single transaction.
    await this.unitOfWork.run(async (ctx) => {
      await this.supportTicketRepository.save(ticket, ctx);
      await this.events.publish(ctx, ...ticket.pullEvents());
    });

    return { id: ticket.id, createdAt: ticket.createdAt };
  }
}
