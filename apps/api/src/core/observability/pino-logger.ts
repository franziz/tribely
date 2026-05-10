import { logger as pino } from '../middleware/logger.js';
import type { Logger } from './logger.port.js';

/**
 * Production adapter that delegates to the shared Pino instance. The Pino
 * logger already honors LOG_LEVEL from env and (in dev) pretty-prints. The
 * port exists to keep application code free of a direct Pino import.
 */
export class PinoLogger implements Logger {
  info(payload: Record<string, unknown>, message: string): void {
    pino.info(payload, message);
  }

  warn(payload: Record<string, unknown>, message: string): void {
    pino.warn(payload, message);
  }

  error(payload: Record<string, unknown>, message: string): void {
    pino.error(payload, message);
  }
}
