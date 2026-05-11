import { describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { JoinRequest } from '../../domain/entities/join-request.js';
import { JOIN_REQUEST_CANCELLED_BY_REQUESTER } from '../../domain/events/cancelled-by-requester.event.js';
import { CancelJoinRequestByRequesterUseCase } from './cancel-join-request-by-requester.usecase.js';
import {
  FakeEventPublisher,
  FakeJoinRequestRepository,
  FakeUnitOfWork,
  FixedClock,
  TEST_TX,
} from './__test__/fakes.js';

const NOW = new Date('2026-05-11T00:00:00Z');
const STARTS = new Date(NOW.getTime() + 7 * 24 * 60 * 60 * 1000);
const ENDS = new Date(STARTS.getTime() + 3 * 60 * 60 * 1000);
const SNAPSHOT = {
  startsAt: STARTS,
  endsAt: ENDS,
  venue: { address: '18 Raffles Quay', city: 'Singapore', latitude: 1.2806, longitude: 103.8504 },
  hostUserId: 'host_1',
};

const seedPending = (repo: FakeJoinRequestRepository): JoinRequest => {
  const jr = JoinRequest.request({
    id: 'jr_1',
    eventId: 'evt_1',
    requesterUserId: 'requester_1',
    now: NOW,
    autoApprove: false,
    hostUserId: 'host_1',
    eventSnapshot: SNAPSHOT,
  });
  jr.pullEvents();
  repo.put(jr);
  return jr;
};

const seedApproved = (repo: FakeJoinRequestRepository): JoinRequest => {
  const jr = JoinRequest.request({
    id: 'jr_1',
    eventId: 'evt_1',
    requesterUserId: 'requester_1',
    now: NOW,
    autoApprove: true,
    hostUserId: 'host_1',
    eventSnapshot: SNAPSHOT,
  });
  jr.pullEvents();
  repo.put(jr);
  return jr;
};

const buildSut = () => {
  const joinRequests = new FakeJoinRequestRepository();
  const publisher = new FakeEventPublisher();
  const uow = new FakeUnitOfWork();
  const clock = new FixedClock(NOW);
  const useCase = new CancelJoinRequestByRequesterUseCase(uow, joinRequests, publisher, clock);
  return { joinRequests, publisher, useCase };
};

describe('CancelJoinRequestByRequesterUseCase', () => {
  it('cancels a pending request and emits previousStatus=pending', async () => {
    const { joinRequests, publisher, useCase } = buildSut();
    seedPending(joinRequests);

    await useCase.execute({ joinRequestId: 'jr_1', actorUserId: 'requester_1' });

    expect(joinRequests.lastFindByIdCtx).toBe(TEST_TX);
    const stored = await joinRequests.findById('jr_1');
    expect(stored?.status).toBe('cancelled');
    expect(publisher.published).toHaveLength(1);
    const ev = publisher.published[0];
    expect(ev?.type).toBe(JOIN_REQUEST_CANCELLED_BY_REQUESTER);
    expect(ev?.payload).toMatchObject({
      id: 'jr_1',
      requesterUserId: 'requester_1',
      previousStatus: 'pending',
    });
  });

  it('cancels an approved request and emits previousStatus=approved (seat freed)', async () => {
    const { joinRequests, publisher, useCase } = buildSut();
    seedApproved(joinRequests);

    await useCase.execute({ joinRequestId: 'jr_1', actorUserId: 'requester_1' });

    expect(joinRequests.lastFindByIdCtx).toBe(TEST_TX);
    const stored = await joinRequests.findById('jr_1');
    expect(stored?.status).toBe('cancelled');
    expect(publisher.published[0]?.payload).toMatchObject({ previousStatus: 'approved' });
  });

  it('returns 404 when the join request does not exist', async () => {
    const { useCase } = buildSut();
    await expect(
      useCase.execute({ joinRequestId: 'missing', actorUserId: 'requester_1' }),
    ).rejects.toThrowError(AppError);
  });

  it('forbids cancellation by anyone other than the requester', async () => {
    const { joinRequests, useCase } = buildSut();
    seedPending(joinRequests);
    await expect(
      useCase.execute({ joinRequestId: 'jr_1', actorUserId: 'someone-else' }),
    ).rejects.toThrowError(/requester/);
  });

  it('propagates ALREADY_CANCELLED from the aggregate on re-cancel', async () => {
    const { joinRequests, useCase } = buildSut();
    const jr = seedPending(joinRequests);
    jr.cancelByRequester(NOW);
    jr.pullEvents();

    try {
      await useCase.execute({ joinRequestId: 'jr_1', actorUserId: 'requester_1' });
      expect.fail('expected throw');
    } catch (err) {
      expect(err).toBeInstanceOf(AppError);
      const e = err as AppError;
      expect(e.code).toBe('CONFLICT');
      expect(e.details).toEqual({ subcode: 'ALREADY_CANCELLED' });
    }
  });

  it('propagates conflict from the aggregate when the request is rejected', async () => {
    const { joinRequests, useCase } = buildSut();
    const jr = seedPending(joinRequests);
    jr.reject({ by: 'host_1', reason: 'full', now: NOW });
    jr.pullEvents();
    await expect(
      useCase.execute({ joinRequestId: 'jr_1', actorUserId: 'requester_1' }),
    ).rejects.toThrowError(/Cannot cancel/);
  });
});
