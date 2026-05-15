export interface HostRatingsReadModel {
  /**
   * Returns the average host rating for the given user, or null if the user
   * has no ratings yet. The threshold for "established host" is ≥4.0 (TRI-33).
   */
  getAverageRatingForHost(hostUserId: string): Promise<number | null>;
}
