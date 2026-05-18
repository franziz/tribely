import type { User } from '@/features/users/domain/entities/user.js';

export interface VerifyPhoneInput {
  userId: string;
  rawPhone: string;
  code: string;
}

export interface VerifyPhoneResult {
  user: User;
}
