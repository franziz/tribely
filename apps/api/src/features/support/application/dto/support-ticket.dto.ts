export interface SubmitSupportTicketInput {
  userId: string;
  category: string;
  message: string;
  reportId?: string;
}

export interface SubmitSupportTicketResult {
  id: string;
  createdAt: Date;
}
