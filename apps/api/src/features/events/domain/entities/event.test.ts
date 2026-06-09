import { describe, expect, it } from 'vitest';
import { AppError } from '@/core/errors/app-error.js';
import { EVENT_CANCELLED } from '../events/event-cancelled.event.js';
import { EVENT_COMPLETED } from '../events/event-completed.event.js';
import { EVENT_CREATED } from '../events/event-created.event.js';
import { EVENT_PUBLISHED } from '../events/event-published.event.js';
import { EVENT_UPDATED } from '../events/event-updated.event.js';
import { Capacity } from '../value-objects/capacity.js';
import { EventCategory } from '../value-objects/event-category.js';
import { VenueCategory } from '../value-objects/venue-category.js';
import { Venue } from '../value-objects/venue.js';
import { Event } from './event.js';

const NOW = new Date('2026-05-11T00:00:00Z');
const STARTS = new Date('2026-06-01T18:00:00Z');
const ENDS = new Date('2026-06-01T22:00:00Z');

const draftEvent = (overrides: Partial<Parameters<typeof Event.create>[0]> = {}): Event => {
  const input = {
    id: 'evt_1',
    hostUserId: 'user_1',
    title: 'Hawker tour at Lau Pa Sat',
    description: 'Meet at the satay street entrance',
    venue: Venue.create({
      address: '18 Raffles Quay, Singapore',
      city: 'Singapore',
      latitude: 1.2806,
      longitude: 103.8504,
    }),
    startsAt: STARTS,
    endsAt: ENDS,
    capacity: Capacity.create(6),
    category: EventCategory.create('food'),
    venueCategory: VenueCategory.create('hawker_centre'),
    costNotes: null,
    approvalMode: 'manual' as const,
    now: NOW,
    ...overrides,
  };
  return Event.create(input);
};

describe('Event', () => {
  describe('create', () => {
    it('starts as draft', () => {
      const e = draftEvent();
      expect(e.status).toBe('draft');
      expect(e.cancellationReason).toBeNull();
      expect(e.createdAt).toEqual(NOW);
      expect(e.updatedAt).toEqual(NOW);
    });

    it('records events.eventCreated with the full snapshot', () => {
      const e = draftEvent();
      const events = e.pullEvents();
      expect(events).toHaveLength(1);
      const ev = events[0];
      expect(ev?.type).toBe(EVENT_CREATED);
      expect(ev?.payload).toMatchObject({
        eventId: 'evt_1',
        hostUserId: 'user_1',
        title: 'Hawker tour at Lau Pa Sat',
        capacity: 6,
        category: 'food',
        venueCategory: 'hawker_centre',
        costNotes: null,
        approvalMode: 'manual',
      });
    });

    it.each(VenueCategory.PUBLIC_VALUES)(
      'create with public venueCategory "%s" succeeds and carries the value in the payload',
      (vc) => {
        const e = draftEvent({ venueCategory: VenueCategory.create(vc) });
        const events = e.pullEvents();
        expect(events).toHaveLength(1);
        expect(events[0]?.payload).toMatchObject({ venueCategory: vc });
        expect(e.venueCategory.value).toBe(vc);
      },
    );

    it.each(
      VenueCategory.VALUES.filter(
        (v): v is (typeof VenueCategory.VALUES)[number] =>
          !(VenueCategory.PUBLIC_VALUES as readonly string[]).includes(v),
      ),
    )(
      'create with private venueCategory "%s" succeeds — no policy enforcement at aggregate level',
      (vc) => {
        // Brief 6 (use-case layer) enforces the public-venue policy.
        // The aggregate just carries the field regardless of category.
        const e = draftEvent({ venueCategory: VenueCategory.create(vc) });
        const events = e.pullEvents();
        expect(events).toHaveLength(1);
        expect(events[0]?.payload).toMatchObject({ venueCategory: vc });
        expect(e.venueCategory.value).toBe(vc);
      },
    );

    it('trims the title', () => {
      const e = draftEvent({ title: '   Sunset hike   ' });
      expect(e.title).toBe('Sunset hike');
    });

    it('normalizes empty / whitespace description to null', () => {
      expect(draftEvent({ description: '' }).description).toBeNull();
      expect(draftEvent({ description: '   ' }).description).toBeNull();
    });

    it('rejects a too-short title', () => {
      expect(() => draftEvent({ title: 'hi' })).toThrowError(AppError);
    });

    it('rejects a too-long title', () => {
      expect(() => draftEvent({ title: 'a'.repeat(121) })).toThrowError(/title/);
    });

    it('rejects a too-long description', () => {
      expect(() => draftEvent({ description: 'd'.repeat(2001) })).toThrowError(/description/);
    });

    it('normalizes empty / whitespace costNotes to null', () => {
      expect(draftEvent({ costNotes: '' }).costNotes).toBeNull();
      expect(draftEvent({ costNotes: '   ' }).costNotes).toBeNull();
    });

    it('stores a valid non-empty costNotes string trimmed', () => {
      const e = draftEvent({ costNotes: '  Host covers drinks  ' });
      expect(e.costNotes).toBe('Host covers drinks');
    });

    it('rejects a too-long costNotes (>200 chars)', () => {
      expect(() => draftEvent({ costNotes: 'x'.repeat(201) })).toThrowError(/costNotes/);
    });

    it('rejects endsAt <= startsAt', () => {
      expect(() => draftEvent({ endsAt: STARTS })).toThrowError(/endsAt/);
      expect(() => draftEvent({ endsAt: new Date(STARTS.getTime() - 1) })).toThrowError(/endsAt/);
    });

    it('rejects startsAt <= now', () => {
      expect(() =>
        draftEvent({ startsAt: NOW, endsAt: new Date(NOW.getTime() + 1000) }),
      ).toThrowError(/startsAt/);
    });
  });

  describe('publish', () => {
    it('transitions draft → published and records eventPublished', () => {
      const e = draftEvent();
      e.pullEvents();
      const at = new Date(NOW.getTime() + 1000);
      e.publish(at);
      expect(e.status).toBe('published');
      expect(e.updatedAt).toEqual(at);
      const events = e.pullEvents();
      expect(events).toHaveLength(1);
      expect(events[0]?.type).toBe(EVENT_PUBLISHED);
    });

    it('is idempotent on already-published', () => {
      const e = draftEvent();
      e.publish(new Date(NOW.getTime() + 1000));
      e.pullEvents();
      e.publish(new Date(NOW.getTime() + 2000));
      expect(e.pullEvents()).toHaveLength(0);
    });

    it('throws when cancelled', () => {
      const e = draftEvent();
      e.cancel('weather', new Date(NOW.getTime() + 1000));
      expect(() => {
        e.publish(new Date(NOW.getTime() + 2000));
      }).toThrowError(/Cannot publish/);
    });

    it('throws when completed', () => {
      const e = draftEvent();
      e.publish(new Date(NOW.getTime() + 1000));
      e.markCompleted(new Date(NOW.getTime() + 2000));
      expect(() => {
        e.publish(new Date(NOW.getTime() + 3000));
      }).toThrowError(/Cannot publish/);
    });
  });

  describe('cancel', () => {
    it('cancels a draft, stores reason, records eventCancelled', () => {
      const e = draftEvent();
      e.pullEvents();
      const at = new Date(NOW.getTime() + 1000);
      e.cancel('  weather  ', at);
      expect(e.status).toBe('cancelled');
      expect(e.cancellationReason).toBe('weather');
      expect(e.updatedAt).toEqual(at);
      const events = e.pullEvents();
      expect(events).toHaveLength(1);
      expect(events[0]?.type).toBe(EVENT_CANCELLED);
      expect(events[0]?.payload).toMatchObject({ reason: 'weather' });
    });

    it('cancels a published event', () => {
      const e = draftEvent();
      e.publish(new Date(NOW.getTime() + 1000));
      e.pullEvents();
      e.cancel('host emergency', new Date(NOW.getTime() + 2000));
      expect(e.status).toBe('cancelled');
    });

    it('rejects empty / whitespace reason', () => {
      const e = draftEvent();
      expect(() => {
        e.cancel('', NOW);
      }).toThrowError(/reason/);
      expect(() => {
        e.cancel('   ', NOW);
      }).toThrowError(/reason/);
    });

    it('rejects a reason longer than 500 chars', () => {
      const e = draftEvent();
      expect(() => {
        e.cancel('x'.repeat(501), NOW);
      }).toThrowError(/500/);
    });

    it('is idempotent on already-cancelled', () => {
      const e = draftEvent();
      e.cancel('weather', new Date(NOW.getTime() + 1000));
      e.pullEvents();
      e.cancel('weather again', new Date(NOW.getTime() + 2000));
      expect(e.pullEvents()).toHaveLength(0);
      expect(e.cancellationReason).toBe('weather'); // first reason preserved
    });

    it('throws when completed', () => {
      const e = draftEvent();
      e.publish(new Date(NOW.getTime() + 1000));
      e.markCompleted(new Date(NOW.getTime() + 2000));
      expect(() => {
        e.cancel('too late', new Date(NOW.getTime() + 3000));
      }).toThrowError(/Cannot cancel/);
    });
  });

  describe('markCompleted', () => {
    it('transitions published → completed and records eventCompleted', () => {
      const e = draftEvent();
      e.publish(new Date(NOW.getTime() + 1000));
      e.pullEvents();
      const at = new Date(NOW.getTime() + 2000);
      e.markCompleted(at);
      expect(e.status).toBe('completed');
      expect(e.updatedAt).toEqual(at);
      const events = e.pullEvents();
      expect(events).toHaveLength(1);
      expect(events[0]?.type).toBe(EVENT_COMPLETED);
    });

    it('throws when still draft', () => {
      const e = draftEvent();
      expect(() => {
        e.markCompleted(new Date(NOW.getTime() + 1000));
      }).toThrowError(/Cannot complete/);
    });

    it('throws when cancelled', () => {
      const e = draftEvent();
      e.cancel('weather', new Date(NOW.getTime() + 1000));
      expect(() => {
        e.markCompleted(new Date(NOW.getTime() + 2000));
      }).toThrowError(/Cannot complete/);
    });

    it('is idempotent on already-completed', () => {
      const e = draftEvent();
      e.publish(new Date(NOW.getTime() + 1000));
      e.markCompleted(new Date(NOW.getTime() + 2000));
      e.pullEvents();
      e.markCompleted(new Date(NOW.getTime() + 3000));
      expect(e.pullEvents()).toHaveLength(0);
    });
  });

  describe('edit', () => {
    const editNow = new Date(NOW.getTime() + 1000);

    it('updates a draft event and records eventUpdated with full snapshot', () => {
      const e = draftEvent();
      e.pullEvents();
      e.edit({ title: 'Updated title', capacity: Capacity.create(10) }, editNow);
      expect(e.title).toBe('Updated title');
      expect(e.capacity.value).toBe(10);
      expect(e.updatedAt).toEqual(editNow);
      const events = e.pullEvents();
      expect(events).toHaveLength(1);
      const ev = events[0];
      expect(ev?.type).toBe(EVENT_UPDATED);
      expect(ev?.payload).toMatchObject({
        eventId: 'evt_1',
        title: 'Updated title',
        capacity: 10,
        category: 'food',
      });
    });

    it('updates a published event', () => {
      const e = draftEvent();
      e.publish(new Date(NOW.getTime() + 500));
      e.pullEvents();
      e.edit({ title: 'New title' }, editNow);
      expect(e.title).toBe('New title');
      expect(e.status).toBe('published');
      expect(e.pullEvents()[0]?.type).toBe(EVENT_UPDATED);
    });

    it('is a no-op when patch matches current state', () => {
      const e = draftEvent();
      e.pullEvents();
      e.edit({ title: e.title }, editNow);
      expect(e.pullEvents()).toHaveLength(0);
      expect(e.updatedAt).toEqual(NOW);
    });

    it('is a no-op when patch is empty', () => {
      const e = draftEvent();
      e.pullEvents();
      e.edit({}, editNow);
      expect(e.pullEvents()).toHaveLength(0);
      expect(e.updatedAt).toEqual(NOW);
    });

    it('trims the title', () => {
      const e = draftEvent();
      e.pullEvents();
      e.edit({ title: '   Trimmed   ' }, editNow);
      expect(e.title).toBe('Trimmed');
    });

    it('normalizes empty / whitespace description to null', () => {
      const e = draftEvent();
      e.pullEvents();
      e.edit({ description: '   ' }, editNow);
      expect(e.description).toBeNull();
    });

    it('updates costNotes and emits eventUpdated with new value', () => {
      const e = draftEvent({ costNotes: null });
      e.pullEvents();
      e.edit({ costNotes: 'Each pays own way' }, editNow);
      expect(e.costNotes).toBe('Each pays own way');
      const events = e.pullEvents();
      expect(events).toHaveLength(1);
      expect(events[0]?.payload).toMatchObject({ costNotes: 'Each pays own way' });
    });

    it('clears costNotes when patched to null', () => {
      const e = draftEvent({ costNotes: 'Some notes' });
      e.pullEvents();
      e.edit({ costNotes: null }, editNow);
      expect(e.costNotes).toBeNull();
    });

    it('clears costNotes when patched to empty string', () => {
      const e = draftEvent({ costNotes: 'Some notes' });
      e.pullEvents();
      e.edit({ costNotes: '' }, editNow);
      expect(e.costNotes).toBeNull();
    });

    it('is a no-op when costNotes is patched with the same value', () => {
      const e = draftEvent({ costNotes: 'Same notes' });
      e.pullEvents();
      e.edit({ costNotes: 'Same notes' }, editNow);
      expect(e.pullEvents()).toHaveLength(0);
      expect(e.updatedAt).toEqual(NOW);
    });

    it('rejects costNotes > 200 chars in edit', () => {
      const e = draftEvent();
      expect(() => {
        e.edit({ costNotes: 'x'.repeat(201) }, editNow);
      }).toThrowError(/costNotes/);
    });

    it('rejects edit when cancelled', () => {
      const e = draftEvent();
      e.cancel('weather', new Date(NOW.getTime() + 500));
      expect(() => {
        e.edit({ title: 'Won’t work' }, editNow);
      }).toThrowError(/Cannot edit/);
    });

    it('rejects edit when completed', () => {
      const e = draftEvent();
      e.publish(new Date(NOW.getTime() + 500));
      e.markCompleted(new Date(NOW.getTime() + 700));
      expect(() => {
        e.edit({ title: 'Won’t work' }, editNow);
      }).toThrowError(/Cannot edit/);
    });

    it('re-validates endsAt > startsAt against the new pair', () => {
      const e = draftEvent();
      expect(() => {
        e.edit({ endsAt: e.startsAt }, editNow);
      }).toThrowError(/endsAt/);
    });

    it('re-validates startsAt > now after edit', () => {
      const e = draftEvent();
      const newStart = new Date(editNow.getTime() - 1);
      expect(() => {
        e.edit({ startsAt: newStart, endsAt: new Date(newStart.getTime() + 1000) }, editNow);
      }).toThrowError(/startsAt/);
    });

    it('rejects a too-short title', () => {
      const e = draftEvent();
      expect(() => {
        e.edit({ title: 'hi' }, editNow);
      }).toThrowError(/title/);
    });

    it('rejects a too-long description', () => {
      const e = draftEvent();
      expect(() => {
        e.edit({ description: 'd'.repeat(2001) }, editNow);
      }).toThrowError(/description/);
    });

    it('changing venueCategory emits eventUpdated with the new value', () => {
      const e = draftEvent({ venueCategory: VenueCategory.create('hawker_centre') });
      e.pullEvents();
      e.edit({ venueCategory: VenueCategory.create('park') }, editNow);
      expect(e.venueCategory.value).toBe('park');
      expect(e.updatedAt).toEqual(editNow);
      const events = e.pullEvents();
      expect(events).toHaveLength(1);
      expect(events[0]?.type).toBe(EVENT_UPDATED);
      expect(events[0]?.payload).toMatchObject({ venueCategory: 'park' });
    });

    it('edit with same venueCategory is a no-op — no event, updatedAt untouched', () => {
      const e = draftEvent({ venueCategory: VenueCategory.create('hawker_centre') });
      e.pullEvents();
      e.edit({ venueCategory: VenueCategory.create('hawker_centre') }, editNow);
      expect(e.pullEvents()).toHaveLength(0);
      expect(e.updatedAt).toEqual(NOW);
    });
  });

  describe('rehydrate', () => {
    it('does not record any events', () => {
      const e = Event.rehydrate({
        id: 'evt_1',
        hostUserId: 'user_1',
        title: 'Hawker tour',
        description: null,
        venue: Venue.create({
          address: 'Lau Pa Sat',
          city: 'Singapore',
          latitude: 1.28,
          longitude: 103.85,
        }),
        startsAt: STARTS,
        endsAt: ENDS,
        capacity: Capacity.create(6),
        category: EventCategory.create('food'),
        venueCategory: VenueCategory.create('hawker_centre'),
        costNotes: null,
        approvalMode: 'manual',
        status: 'published',
        cancellationReason: null,
        createdAt: NOW,
        updatedAt: NOW,
      });
      expect(e.pullEvents()).toHaveLength(0);
      expect(e.status).toBe('published');
    });

    it('round-trips venueCategory through rehydrate', () => {
      const e = Event.rehydrate({
        id: 'evt_1',
        hostUserId: 'user_1',
        title: 'Hawker tour',
        description: null,
        venue: Venue.create({
          address: 'Lau Pa Sat',
          city: 'Singapore',
          latitude: 1.28,
          longitude: 103.85,
        }),
        startsAt: STARTS,
        endsAt: ENDS,
        capacity: Capacity.create(6),
        category: EventCategory.create('food'),
        venueCategory: VenueCategory.create('museum'),
        costNotes: null,
        approvalMode: 'manual',
        status: 'draft',
        cancellationReason: null,
        createdAt: NOW,
        updatedAt: NOW,
      });
      expect(e.venueCategory.value).toBe('museum');
      expect(e.pullEvents()).toHaveLength(0);
    });
  });
});
