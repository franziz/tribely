import { describe, expect, it } from 'vitest';
import type { Consumer } from '../consumer.port.js';
import { ConsumerRegistry } from '../consumer-registry.js';

const fakeConsumer = (
  overrides: Partial<Consumer> & Pick<Consumer, 'name' | 'topic'>,
): Consumer => ({
  handle: () => Promise.resolve(),
  ...overrides,
});

describe('ConsumerRegistry', () => {
  it('register + all() returns the registered consumer', () => {
    const registry = new ConsumerRegistry();
    const c = fakeConsumer({ name: 'a.x', topic: 'users.userRegistered' });
    registry.register(c);
    expect(registry.all()).toEqual([c]);
  });

  it('rejects duplicate names', () => {
    const registry = new ConsumerRegistry();
    registry.register(fakeConsumer({ name: 'a.x', topic: 't1' }));
    expect(() => {
      registry.register(fakeConsumer({ name: 'a.x', topic: 't2' }));
    }).toThrow(/already registered/);
  });

  it('forTopic filters by event type', () => {
    const registry = new ConsumerRegistry();
    const a = fakeConsumer({ name: 'feat.aOnX', topic: 'users.userRegistered' });
    const b = fakeConsumer({ name: 'feat.bOnX', topic: 'users.userRegistered' });
    const c = fakeConsumer({ name: 'feat.cOnY', topic: 'auth.userSignedIn' });
    registry.register(a);
    registry.register(b);
    registry.register(c);
    expect(registry.forTopic('users.userRegistered')).toEqual([a, b]);
    expect(registry.forTopic('auth.userSignedIn')).toEqual([c]);
    expect(registry.forTopic('nope.never')).toEqual([]);
  });

  it('has + get lookups by name', () => {
    const registry = new ConsumerRegistry();
    const c = fakeConsumer({ name: 'a.x', topic: 't' });
    registry.register(c);
    expect(registry.has('a.x')).toBe(true);
    expect(registry.has('a.y')).toBe(false);
    expect(registry.get('a.x')).toBe(c);
    expect(registry.get('a.y')).toBeUndefined();
  });
});
