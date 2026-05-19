/**
 * Canonical interface for checking block relationships between users.
 *
 * This is the SOT definition. The stub in
 * `reviews/application/ports/check-blocked.port.ts` is removed in Brief 1C;
 * all consumers now import from here.
 *
 * The concrete implementation is `RepositoryCheckBlockedAdapter` in
 * `user-blocks/application/adapters/`. Block checks are BIDIRECTIONAL:
 * A blocks B and B blocks A are both caught.
 */
export interface CheckBlockedPort {
  /**
   * Returns the subset of `candidateIds` that the `viewerId` has blocked
   * OR that have blocked `viewerId`. The caller should exclude these IDs
   * from any response visible to `viewerId`.
   */
  filterBlocked(input: { viewerId: string; candidateIds: string[] }): Promise<Set<string>>;

  /**
   * Returns true if `viewerId` has blocked `targetId` OR `targetId` has
   * blocked `viewerId`.
   */
  isBlocked(input: { viewerId: string; targetId: string }): Promise<boolean>;
}
