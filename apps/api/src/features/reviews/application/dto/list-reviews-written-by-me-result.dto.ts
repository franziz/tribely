export interface MyReviewRow {
  id: string;
  eventId: string;
  raterUserId: string;
  ratedUserId: string;
  rating: number;
  comment: string | null;
  hidden: boolean;
  hiddenAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface ListReviewsWrittenByMeResult {
  rows: MyReviewRow[];
  nextCursor: string | null;
}
