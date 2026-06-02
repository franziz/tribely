import { describe, expect, it } from 'vitest';
import {
  cancelEventBodySchema,
  createEventBodySchema,
  listEventsQuerySchema,
  updateEventBodySchema,
} from './event.schemas.js';

const baseCreate = {
  title: 'Hawker tour',
  description: 'Meet at the satay street',
  venue: {
    address: '18 Raffles Quay',
    city: 'Singapore',
    latitude: 1.28,
    longitude: 103.85,
    category: 'cafe',
  },
  startsAt: '2026-06-01T18:00:00Z',
  endsAt: '2026-06-01T22:00:00Z',
  capacity: 6,
  category: 'food',
  approvalMode: 'manual',
};

describe('createEventBodySchema', () => {
  it('accepts a fully-populated valid body', () => {
    expect(createEventBodySchema.parse(baseCreate)).toBeDefined();
  });

  it('rejects endsAt <= startsAt', () => {
    expect(() =>
      createEventBodySchema.parse({ ...baseCreate, endsAt: baseCreate.startsAt }),
    ).toThrowError(/endsAt/);
  });

  it('rejects unknown category', () => {
    expect(() => createEventBodySchema.parse({ ...baseCreate, category: 'nope' })).toThrowError();
  });

  it('rejects capacity below the minimum', () => {
    expect(() => createEventBodySchema.parse({ ...baseCreate, capacity: 1 })).toThrowError();
  });

  it('accepts costNotes as a non-empty string', () => {
    const result = createEventBodySchema.parse({ ...baseCreate, costNotes: 'Each pays own way' });
    expect(result.costNotes).toBe('Each pays own way');
  });

  it('accepts costNotes as null', () => {
    const result = createEventBodySchema.parse({ ...baseCreate, costNotes: null });
    expect(result.costNotes).toBeNull();
  });

  it('accepts omitted costNotes (optional)', () => {
    const result = createEventBodySchema.parse(baseCreate);
    expect(result.costNotes).toBeUndefined();
  });

  it('rejects costNotes exceeding 200 characters', () => {
    expect(() =>
      createEventBodySchema.parse({ ...baseCreate, costNotes: 'x'.repeat(201) }),
    ).toThrowError(/costNotes/);
  });

  it('silently strips legacy costSplit field (no strict mode)', () => {
    const result = createEventBodySchema.parse({ ...baseCreate, costSplit: 'own' });
    expect(result).not.toHaveProperty('costSplit');
  });
});

describe('updateEventBodySchema', () => {
  it('accepts a single-field update', () => {
    expect(updateEventBodySchema.parse({ title: 'Renamed' })).toBeDefined();
  });

  it('rejects an empty body', () => {
    expect(() => updateEventBodySchema.parse({})).toThrowError(/At least one field/);
  });

  it('accepts description=null (explicit clear)', () => {
    expect(updateEventBodySchema.parse({ description: null })).toEqual({ description: null });
  });

  it('accepts costNotes string', () => {
    const result = updateEventBodySchema.parse({ costNotes: 'Host covers drinks' });
    expect(result.costNotes).toBe('Host covers drinks');
  });

  it('accepts costNotes=null (explicit clear)', () => {
    const result = updateEventBodySchema.parse({ costNotes: null });
    expect(result.costNotes).toBeNull();
  });

  it('rejects costNotes exceeding 200 characters', () => {
    expect(() =>
      updateEventBodySchema.parse({ costNotes: 'x'.repeat(201) }),
    ).toThrowError(/costNotes/);
  });
});

describe('cancelEventBodySchema', () => {
  it('accepts an empty body', () => {
    expect(cancelEventBodySchema.parse({})).toEqual({});
  });

  it('accepts a reason string', () => {
    expect(cancelEventBodySchema.parse({ reason: 'weather' })).toEqual({ reason: 'weather' });
  });

  it('rejects a reason longer than 500 chars', () => {
    expect(() => cancelEventBodySchema.parse({ reason: 'x'.repeat(501) })).toThrowError();
  });
});

describe('listEventsQuerySchema', () => {
  it('defaults limit to 20 when omitted', () => {
    expect(listEventsQuerySchema.parse({}).limit).toBe(20);
  });

  it('coerces a numeric-string limit', () => {
    expect(listEventsQuerySchema.parse({ limit: '15' }).limit).toBe(15);
  });

  it('rejects limit > 50', () => {
    expect(() => listEventsQuerySchema.parse({ limit: '60' })).toThrowError();
  });

  it('rejects limit < 1', () => {
    expect(() => listEventsQuerySchema.parse({ limit: '0' })).toThrowError();
  });

  it('rejects unknown category', () => {
    expect(() => listEventsQuerySchema.parse({ category: 'whatever' })).toThrowError();
  });

  it('accepts a cursor string', () => {
    expect(listEventsQuerySchema.parse({ cursor: 'abc123' }).cursor).toBe('abc123');
  });
});
