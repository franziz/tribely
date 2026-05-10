import { beforeEach, describe, expect, it } from 'vitest';
import type { Db } from '../../db/prisma.js';
import type { Consumer } from '../consumer.port.js';
import { ConsumerRegistry } from '../consumer-registry.js';
import { OutboxDispatcher } from '../outbox-dispatcher.js';
import { FakePrisma } from './fake-prisma.js';

/**
 * The fake Prisma is structurally compatible with the methods OutboxDispatcher
 * calls. TypeScript's structural typing accepts the cast.
 */
const asDb = (fake: FakePrisma): Db => fake as unknown as Db;

const TOPIC_A = 'test.topicA';
const TOPIC_B = 'test.topicB';

describe('OutboxDispatcher (per-consumer offsets)', () => {
  let fake: FakePrisma;
  let registry: ConsumerRegistry;

  beforeEach(() => {
    fake = new FakePrisma();
    registry = new ConsumerRegistry();
  });

  const buildDispatcher = () =>
    new OutboxDispatcher(asDb(fake), registry, {
      settleDelaySeconds: 0,
      defaultMaxAttempts: 3,
    });

  it('advances committedSeq on success', async () => {
    const seen: bigint[] = [];
    const consumer: Consumer = {
      name: 'test.success',
      topic: TOPIC_A,
      handle: (event) => {
        seen.push(BigInt(event.aggregateId));
        return Promise.resolve();
      },
    };
    registry.register(consumer);
    fake.insertEvent({
      seq: 1n,
      type: TOPIC_A,
      aggregateId: '1',
    });

    await buildDispatcher().tickOnce();

    expect(fake.getOffset('test.success')?.committedSeq).toBe(1n);
    expect(fake.getOffset('test.success')?.inFlightSeq).toBeNull();
    expect(fake.getOffset('test.success')?.attempts).toBe(0);
    expect(seen).toEqual([1n]);
  });

  it('per-consumer failure isolation: failing consumer blocks, succeeding one advances', async () => {
    registry.register({
      name: 'test.failer',
      topic: TOPIC_A,
      handle: () => Promise.reject(new Error('boom')),
    });
    registry.register({
      name: 'test.succeeder',
      topic: TOPIC_A,
      handle: () => Promise.resolve(),
    });
    fake.insertEvent({ seq: 10n, type: TOPIC_A, aggregateId: '10' });

    await buildDispatcher().tickOnce();

    expect(fake.getOffset('test.failer')?.inFlightSeq).toBe(10n);
    expect(fake.getOffset('test.failer')?.committedSeq).toBe(0n);
    expect(fake.getOffset('test.failer')?.attempts).toBe(1);
    expect(fake.getOffset('test.failer')?.lastError).toBe('boom');

    expect(fake.getOffset('test.succeeder')?.committedSeq).toBe(10n);
    expect(fake.getOffset('test.succeeder')?.inFlightSeq).toBeNull();
  });

  it('retries the same inFlightSeq until success', async () => {
    let attempts = 0;
    registry.register({
      name: 'test.flaky',
      topic: TOPIC_A,
      handle: () => {
        attempts += 1;
        if (attempts < 3) return Promise.reject(new Error(`boom ${String(attempts)}`));
        return Promise.resolve();
      },
    });
    fake.insertEvent({ seq: 5n, type: TOPIC_A });
    const dispatcher = buildDispatcher();

    await dispatcher.tickOnce(); // attempt 1 — fail
    await dispatcher.tickOnce(); // attempt 2 — fail
    await dispatcher.tickOnce(); // attempt 3 — success

    expect(attempts).toBe(3);
    expect(fake.getOffset('test.flaky')?.committedSeq).toBe(5n);
    expect(fake.getOffset('test.flaky')?.inFlightSeq).toBeNull();
    expect(fake.getOffset('test.flaky')?.attempts).toBe(0);
    expect(fake.getOffset('test.flaky')?.lastError).toBeNull();
  });

  it('blocks consumer once attempts >= maxAttempts (default 3 in tests)', async () => {
    registry.register({
      name: 'test.alwaysFails',
      topic: TOPIC_A,
      handle: () => Promise.reject(new Error('always')),
    });
    fake.insertEvent({ seq: 1n, type: TOPIC_A });
    const dispatcher = buildDispatcher();

    await dispatcher.tickOnce(); // attempt 1
    await dispatcher.tickOnce(); // attempt 2
    await dispatcher.tickOnce(); // attempt 3 — should hit maxAttempts and block

    expect(fake.getOffset('test.alwaysFails')?.blockedAt).not.toBeNull();
    expect(fake.getOffset('test.alwaysFails')?.attempts).toBe(3);

    // Subsequent ticks no-op (blocked).
    const beforeAttempts = fake.getOffset('test.alwaysFails')?.attempts;
    await dispatcher.tickOnce();
    expect(fake.getOffset('test.alwaysFails')?.attempts).toBe(beforeAttempts);
  });

  it('honors per-consumer maxAttempts override', async () => {
    registry.register({
      name: 'test.oneShot',
      topic: TOPIC_A,
      maxAttempts: 1,
      handle: () => Promise.reject(new Error('nope')),
    });
    fake.insertEvent({ seq: 1n, type: TOPIC_A });
    await buildDispatcher().tickOnce();

    expect(fake.getOffset('test.oneShot')?.blockedAt).not.toBeNull();
  });

  it('events filter by topic — consumer only sees its topic', async () => {
    const consumerASeen: bigint[] = [];
    const consumerBSeen: bigint[] = [];
    registry.register({
      name: 'test.consumerA',
      topic: TOPIC_A,
      handle: (event) => {
        consumerASeen.push(BigInt(event.aggregateId));
        return Promise.resolve();
      },
    });
    registry.register({
      name: 'test.consumerB',
      topic: TOPIC_B,
      handle: (event) => {
        consumerBSeen.push(BigInt(event.aggregateId));
        return Promise.resolve();
      },
    });
    fake.insertEvent({ seq: 1n, type: TOPIC_A, aggregateId: '101' });
    fake.insertEvent({ seq: 2n, type: TOPIC_B, aggregateId: '202' });
    fake.insertEvent({ seq: 3n, type: TOPIC_A, aggregateId: '103' });

    const dispatcher = buildDispatcher();
    await dispatcher.tickOnce(); // each consumer drains one event
    await dispatcher.tickOnce(); // consumer A drains its second; B has none left

    expect(consumerASeen).toEqual([101n, 103n]);
    expect(consumerBSeen).toEqual([202n]);
  });

  it('settle delay holds back events newer than the boundary', async () => {
    registry.register({
      name: 'test.settleSensitive',
      topic: TOPIC_A,
      handle: () => Promise.resolve(),
    });
    // Force a settle delay of 60s, then insert a fresh-now event.
    const dispatcher = new OutboxDispatcher(asDb(fake), registry, {
      settleDelaySeconds: 60,
    });
    fake.insertEvent({
      seq: 1n,
      type: TOPIC_A,
      occurredAt: new Date(), // now — well within the 60s window
    });

    await dispatcher.tickOnce();

    expect(fake.getOffset('test.settleSensitive')?.committedSeq).toBe(0n);
    expect(fake.getOffset('test.settleSensitive')?.inFlightSeq).toBeNull();
  });

  it('reports outcomes to the wired reporter', async () => {
    const outcomes: Array<{ phase: string; consumerName: string; eventSeq: bigint }> = [];
    const dispatcher = buildDispatcher();
    dispatcher.setOutcomeReporter({
      onOutcome: (input) => {
        outcomes.push({
          phase: input.phase,
          consumerName: input.consumerName,
          eventSeq: input.eventSeq,
        });
        return Promise.resolve();
      },
    });

    registry.register({
      name: 'test.reporterOk',
      topic: TOPIC_A,
      handle: () => Promise.resolve(),
    });
    fake.insertEvent({ seq: 1n, type: TOPIC_A });
    await dispatcher.tickOnce();

    expect(outcomes).toEqual([
      { phase: 'dispatched', consumerName: 'test.reporterOk', eventSeq: 1n },
    ]);
  });
});
