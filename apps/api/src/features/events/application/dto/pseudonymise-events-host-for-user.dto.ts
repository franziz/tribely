export interface PseudonymiseEventsHostForUserInput {
  userId: string;
  pseudonymHostId: string;
}

export interface PseudonymiseEventsHostForUserResult {
  updatedCount: number;
}
