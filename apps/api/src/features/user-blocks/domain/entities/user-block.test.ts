import { describe, expect, it } from 'vitest';
import { UserBlock } from './user-block.js';
import { USER_BLOCKED } from '../events/user-blocked.event.js';
import { USER_UNBLOCKED } from '../events/user-unblocked.event.js';

const NOW = new Date('2026-05-19T10:00:00Z');

describe('UserBlock.initiate', () => {
  it('creates a block and records userBlocked event', () => {
    const block = UserBlock.initiate({
      id: 'block-1',
      initiatorUserId: 'user-A',
      blockedUserId: 'user-B',
      now: NOW,
    });

    expect(block.id).toBe('block-1');
    expect(block.initiatorUserId).toBe('user-A');
    expect(block.blockedUserId).toBe('user-B');
    expect(block.createdAt).toBe(NOW);

    const events = block.pullEvents();
    expect(events).toHaveLength(1);
    expect(events[0]?.type).toBe(USER_BLOCKED);
    expect(events[0]?.payload).toMatchObject({
      id: 'block-1',
      initiatorUserId: 'user-A',
      blockedUserId: 'user-B',
    });
  });

  it('throws CannotBlockSelf when initiatorUserId === blockedUserId', () => {
    expect(() =>
      UserBlock.initiate({
        id: 'block-self',
        initiatorUserId: 'user-A',
        blockedUserId: 'user-A',
        now: NOW,
      }),
    ).toThrow('Cannot block yourself');
  });

  it('pullEvents clears the internal buffer after first call', () => {
    const block = UserBlock.initiate({
      id: 'block-2',
      initiatorUserId: 'user-A',
      blockedUserId: 'user-B',
      now: NOW,
    });
    block.pullEvents(); // drain
    expect(block.pullEvents()).toHaveLength(0);
  });
});

describe('UserBlock.rehydrate', () => {
  it('rehydrates without recording events', () => {
    const block = UserBlock.rehydrate({
      id: 'block-3',
      initiatorUserId: 'user-A',
      blockedUserId: 'user-B',
      createdAt: NOW,
    });

    expect(block.id).toBe('block-3');
    expect(block.pullEvents()).toHaveLength(0);
  });
});

describe('UserBlock.initiateUnblock', () => {
  it('records userUnblocked event', () => {
    const block = UserBlock.rehydrate({
      id: 'block-4',
      initiatorUserId: 'user-A',
      blockedUserId: 'user-B',
      createdAt: NOW,
    });

    block.initiateUnblock(NOW);

    const events = block.pullEvents();
    expect(events).toHaveLength(1);
    expect(events[0]?.type).toBe(USER_UNBLOCKED);
    expect(events[0]?.payload).toMatchObject({
      id: 'block-4',
      initiatorUserId: 'user-A',
      blockedUserId: 'user-B',
    });
  });
});
