/**
 * Result shape for capability queries on the authenticated user.
 * The capability gate behind `canPostPrivateVenue` is the TRI-33
 * first-event-must-be-public enforcement; future fields extend
 * append-only without versioning.
 */
export interface UserCapabilitiesResult {
  canPostPrivateVenue: boolean;
}
