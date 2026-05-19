/**
 * Read model returned by SurfacePendingCheckInsUseCase.
 *
 * `eventTitle` is server-side truncated to 40 chars + ellipsis (…) when
 * longer — presentable for in-app prompts without extra client formatting.
 */
export interface PendingCheckIn {
  id: string;
  eventId: string;
  eventTitle: string;
  hostDisplayName: string;
  endedAt: Date;
  createdAt: Date;
}
