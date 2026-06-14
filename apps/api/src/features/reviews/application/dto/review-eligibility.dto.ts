/** Result shape for GET /events/:eventId/review-eligibility. */
export interface ReviewEligibilityDto {
  eligible: boolean;
  /** The user ID the viewer would rate. null when ineligible. */
  ratedUserId: string | null;
  /** Display name of the host. null when ineligible. */
  hostDisplayName: string | null;
}
