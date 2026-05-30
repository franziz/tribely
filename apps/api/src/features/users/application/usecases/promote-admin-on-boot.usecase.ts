import type { UnitOfWork } from '@/core/db/unit-of-work.port.js';
import type { Clock } from '@/features/auth/domain/ports/clock.port.js';
import { Email } from '../../domain/value-objects/email.js';
import type { UserRepository } from '../../domain/repositories/user.repository.js';

export type PromoteAdminOnBootResult =
  | { outcome: 'promoted'; userId: string; email: string }
  | { outcome: 'already-admin' }
  | { outcome: 'no-such-user' };

/**
 * Boot-time use case that promotes the user identified by `input.email` to
 * admin, if they are not already an admin.
 *
 * Designed to be called once per boot from `index.ts` inside a
 * `runAsSystem('boot.admin-bootstrap', ...)` wrapper. Idempotent across N
 * boots — re-running on an already-admin user is a no-op (no DB write, no
 * event emission).
 *
 * Logging is intentionally absent — the boot caller (`index.ts`) logs based
 * on the returned outcome so it can apply different severity levels per
 * outcome without coupling this use case to a logger implementation.
 *
 * A malformed `input.email` propagates as a thrown AppError (fail-fast on
 * operator misconfig).
 */
export class PromoteAdminOnBootUseCase {
  constructor(
    private readonly unitOfWork: UnitOfWork,
    private readonly users: UserRepository,
    private readonly clock: Clock,
  ) {}

  async execute(input: { email: string }): Promise<PromoteAdminOnBootResult> {
    // Let a malformed email throw — misconfig should crash boot loudly.
    const email = Email.create(input.email);

    const user = await this.users.findByEmail(email);

    if (!user) {
      return { outcome: 'no-such-user' };
    }

    if (user.isAdmin) {
      return { outcome: 'already-admin' };
    }

    user.promote(this.clock.now());

    await this.unitOfWork.run((ctx) => this.users.save(user, ctx));

    return { outcome: 'promoted', userId: user.id, email: email.value };
  }
}
