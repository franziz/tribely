import type { Event } from '../../domain/entities/event.js';

/**
 * Minimal public projection of the host User. Other features (and the user's
 * own `/auth/me` response) may expose more, but the public event surface
 * intentionally hides email / verification timestamps to limit PII leakage.
 * `isVerified` is the only verification-related field exposed — it is derived
 * from the canonical TRI-86 projection, never a raw timestamp.
 */
export interface PublicHost {
  id: string;
  displayName: string;
  isVerified: boolean;
}

export interface EventWithHost {
  event: Event;
  host: PublicHost;
}
