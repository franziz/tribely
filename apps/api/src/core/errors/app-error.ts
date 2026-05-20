export type AppErrorCode =
  | 'VALIDATION_ERROR'
  | 'UNAUTHORIZED'
  | 'FORBIDDEN'
  | 'EMAIL_NOT_VERIFIED'
  | 'PHONE_NOT_VERIFIED'
  | 'NOT_FOUND'
  | 'CONFLICT'
  | 'UNPROCESSABLE'
  | 'INTERNAL';

export class AppError extends Error {
  readonly code: AppErrorCode;
  readonly status: number;
  readonly details?: unknown;

  constructor(code: AppErrorCode, message: string, status: number, details?: unknown) {
    super(message);
    this.name = 'AppError';
    this.code = code;
    this.status = status;
    this.details = details;
  }

  static validation(message: string, details?: unknown): AppError {
    return new AppError('VALIDATION_ERROR', message, 400, details);
  }

  static unauthorized(message = 'Unauthorized'): AppError {
    return new AppError('UNAUTHORIZED', message, 401);
  }

  static forbidden(message = 'Forbidden', details?: unknown): AppError {
    return new AppError('FORBIDDEN', message, 403, details);
  }

  static emailNotVerified(message = 'Email not verified'): AppError {
    return new AppError('EMAIL_NOT_VERIFIED', message, 403);
  }

  static phoneNotVerified(message = 'Phone not verified'): AppError {
    return new AppError('PHONE_NOT_VERIFIED', message, 403);
  }

  static notFound(message = 'Not found', details?: unknown): AppError {
    return new AppError('NOT_FOUND', message, 404, details);
  }

  static conflict(message: string, details?: unknown): AppError {
    return new AppError('CONFLICT', message, 409, details);
  }

  static unprocessable(message: string, details?: unknown): AppError {
    return new AppError('UNPROCESSABLE', message, 422, details);
  }

  static internal(message = 'Internal server error'): AppError {
    return new AppError('INTERNAL', message, 500);
  }
}
