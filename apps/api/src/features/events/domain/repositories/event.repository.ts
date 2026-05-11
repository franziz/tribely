import type { TxContext } from '@/core/db/unit-of-work.port.js';
import type { Event } from '../entities/event.js';

/**
 * Repository for the Event aggregate.
 *
 * Minimal surface for TRI-9 (aggregate + persistence only). Query methods
 * with filters (city, category, time window, pagination) land with the
 * `GET /events` HTTP endpoint in TRI-19 — adding methods later is non-
 * breaking, so we don't speculate the shape now.
 */
export interface EventRepository {
  findById(id: string, ctx?: TxContext): Promise<Event | null>;
  save(event: Event, ctx?: TxContext): Promise<void>;
}
