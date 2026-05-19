/**
 * Port for checking block relationships between users.
 *
 * TODO: This is a stub interface. Brief 1C will introduce the canonical
 * interface in `user-blocks/application/ports/check-blocked.port.ts` and
 * the container will swap the binding from the no-op adapter to the real
 * implementation. All consumers of this port will be updated to import from
 * the canonical location at that point.
 *
 * The no-op adapter in container.ts returns empty sets / false for now,
 * meaning blocks are not enforced until Brief 1C lands.
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
