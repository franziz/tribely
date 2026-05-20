export interface ReviewPrompt {
  eventId: string;
  eventTitle: string;
  eventEndedAt: string;
  ratedUserId: string;
  ratedUserDisplayName: string;
  ratedUserAvatarUrl: string | null;
}

export interface ListPendingReviewPromptsResult {
  prompt: ReviewPrompt | null;
}
