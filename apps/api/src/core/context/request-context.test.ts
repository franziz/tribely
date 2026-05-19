import { describe, expect, it } from 'vitest';
import { getRequestContext, runWithContext, upgradeActorUserId } from './request-context.js';
import { runAsSystem } from './system-context.js';

describe('request-context', () => {
  describe('outside any frame', () => {
    it('getRequestContext returns null', () => {
      expect(getRequestContext()).toBeNull();
    });
  });

  describe('runWithContext', () => {
    it('exposes the supplied context inside the frame', async () => {
      await runWithContext({ requestId: 'req_1', actorUserId: null }, () => {
        expect(getRequestContext()).toEqual({
          requestId: 'req_1',
          actorUserId: null,
        });
      });
    });

    it('context survives across awaits', async () => {
      await runWithContext({ requestId: 'req_2', actorUserId: 'u_1' }, async () => {
        await new Promise((r) => setTimeout(r, 1));
        expect(getRequestContext()?.requestId).toBe('req_2');
        expect(getRequestContext()?.actorUserId).toBe('u_1');
      });
    });

    it('frames nest independently', async () => {
      await runWithContext({ requestId: 'outer', actorUserId: null }, async () => {
        expect(getRequestContext()?.requestId).toBe('outer');
        await runWithContext({ requestId: 'inner', actorUserId: null }, () => {
          expect(getRequestContext()?.requestId).toBe('inner');
        });
        expect(getRequestContext()?.requestId).toBe('outer');
      });
    });

    it('frame is gone after the closure resolves', async () => {
      await runWithContext({ requestId: 'req_3', actorUserId: null }, () => {
        // body
      });
      expect(getRequestContext()).toBeNull();
    });
  });

  describe('upgradeActorUserId', () => {
    it('replaces actorUserId without changing requestId', async () => {
      await runWithContext({ requestId: 'req_4', actorUserId: null }, async () => {
        await upgradeActorUserId('u_42', () => {
          const ctx = getRequestContext();
          expect(ctx?.requestId).toBe('req_4');
          expect(ctx?.actorUserId).toBe('u_42');
        });
      });
    });

    it('throws when called outside a frame', () => {
      // upgradeActorUserId throws synchronously when no frame exists —
      // the error propagates before the closure ever runs. The `void`
      // satisfies no-floating-promises since the return type union
      // includes Promise.
      expect(() => {
        void upgradeActorUserId('u_x', () => undefined);
      }).toThrow(/outside a request context/);
    });
  });

  describe('runAsSystem', () => {
    it('opens a frame with system: prefix and a generated requestId', async () => {
      await runAsSystem('test.boot', () => {
        const ctx = getRequestContext();
        expect(ctx).not.toBeNull();
        expect(ctx?.requestId).toMatch(/^system:test\.boot:/);
        expect(ctx?.actorUserId).toBeNull();
      });
    });

    it('produces unique requestIds across calls', async () => {
      const ids: string[] = [];
      await runAsSystem('test.dup', () => {
        ids.push(getRequestContext()?.requestId ?? '');
      });
      await runAsSystem('test.dup', () => {
        ids.push(getRequestContext()?.requestId ?? '');
      });
      expect(ids[0]).not.toBe(ids[1]);
    });
  });
});
