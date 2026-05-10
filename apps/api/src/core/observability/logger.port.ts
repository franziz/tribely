/**
 * Outbound port for structured logging from application use cases. The
 * production adapter wraps Pino (the existing `core/middleware/logger.ts`
 * instance); tests inject a fake to assert what was logged.
 *
 * Why a port at all: keeps application/use-case code free of an
 * infrastructure import (Pino) and makes log assertions explicit in tests
 * rather than mocking module imports.
 */
export interface Logger {
  info(payload: Record<string, unknown>, message: string): void;
  warn(payload: Record<string, unknown>, message: string): void;
  error(payload: Record<string, unknown>, message: string): void;
}
