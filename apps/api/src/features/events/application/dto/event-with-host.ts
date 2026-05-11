import type { Event } from '../../domain/entities/event.js';

/**
 * Minimal public projection of the host User. Other features (and the user's
 * own `/auth/me` response) may expose more, but the public event surface
 * intentionally hides email / verification timestamps to limit PII leakage.
 */
export interface PublicHost {
  id: string;
  displayName: string;
}

export interface EventWithHost {
  event: Event;
  host: PublicHost;
}
