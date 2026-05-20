/** A review row returned to the caller, shaped for the HTTP response. */
export interface ReviewForUserRow {
  id: string;
  eventId: string;
  raterUserId: string;
  ratedUserId: string;
  /** null when visibility === 'blind-mutual-pending' */
  rating: number | null;
  /** null when visibility === 'blind-mutual-pending' */
  comment: string | null;
  /** true when the review is hidden (only returned when viewer === author) */
  hidden: boolean;
  /** true when the review is in the mutual-window blind spot */
  hiddenForMutualWindow: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface ListReviewsForUserResult {
  rows: ReviewForUserRow[];
  nextCursor: string | null;
}
