import { describe, expect, it } from 'vitest';
import type { ConsumerContext } from '@/core/events/consumer.port.js';
import type { SignOutAllInput } from '../../application/usecases/sign-out-all.usecase.js';
import type { SignOutAllUseCase } from '../../application/usecases/sign-out-all.usecase.js';
import { PASSWORD_RESET, passwordReset } from '../../domain/events/password-reset.event.js';
import { signOutAllOnPasswordReset } from './sign-out-all-on-password-reset.consumer.js';

const fakeConsumerCtx = (): ConsumerContext => ({
  requestId: 'req_test',
  actorUserId: null,
  attempt: 1,
});

class StubSignOutAll {
  readonly calls: SignOutAllInput[] = [];
  execute(input: SignOutAllInput): Promise<{ revokedCount: number }> {
    this.calls.push(input);
    return Promise.resolve({ revokedCount: 0 });
  }
}

describe('signOutAllOnPasswordReset', () => {
  it('subscribes to auth.passwordReset with the canonical consumer name', () => {
    const stub = new StubSignOutAll();
    const consumer = signOutAllOnPasswordReset({
      signOutAll: stub as unknown as SignOutAllUseCase,
    });
    expect(consumer.name).toBe('auth.signOutAllOnPasswordReset');
    expect(consumer.topic).toBe(PASSWORD_RESET);
  });

  it('invokes SignOutAllUseCase with reason=password_reset and the userId from the event payload', async () => {
    const stub = new StubSignOutAll();
    const consumer = signOutAllOnPasswordReset({
      signOutAll: stub as unknown as SignOutAllUseCase,
    });

    const event = passwordReset({
      userId: 'user_42',
      resetAt: new Date('2026-02-02T00:00:00Z').toISOString(),
    });

    await consumer.handle(event, fakeConsumerCtx());

    expect(stub.calls).toEqual([{ userId: 'user_42', reason: 'password_reset' }]);
  });

  it('is idempotent under at-least-once redelivery (use case is called twice with the same input)', async () => {
    const stub = new StubSignOutAll();
    const consumer = signOutAllOnPasswordReset({
      signOutAll: stub as unknown as SignOutAllUseCase,
    });

    const event = passwordReset({
      userId: 'user_42',
      resetAt: new Date('2026-02-02T00:00:00Z').toISOString(),
    });

    await consumer.handle(event, fakeConsumerCtx());
    await consumer.handle(event, fakeConsumerCtx());

    expect(stub.calls).toEqual([
      { userId: 'user_42', reason: 'password_reset' },
      { userId: 'user_42', reason: 'password_reset' },
    ]);
    // The use case itself is idempotent (revokes only active tokens, no-ops on
    // empty set). The consumer delegating verbatim each time is the correct
    // shape — the use case absorbs the redelivery.
  });
});
