import winston from 'winston';
import { config } from '../config';

/**
 * Creates and configures the Winston logger
 */
export function createLogger(): winston.Logger {
  const logger = winston.createLogger({
    level: config.logLevel,
    format: winston.format.combine(
      winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
      winston.format.errors({ stack: true }),
      winston.format.splat(),
      winston.format.json()
    ),
    defaultMeta: { service: 'reflex-agent' },
    transports: [
      // Console output with colors
      new winston.transports.Console({
        format: winston.format.combine(
          winston.format.colorize(),
          winston.format.printf(({ level, message, timestamp, ...metadata }) => {
            let msg = `${timestamp} [${level}]: ${message}`;
            
            // Add metadata if present
            if (Object.keys(metadata).length > 0) {
              // Filter out service name
              const { service, ...rest } = metadata;
              if (Object.keys(rest).length > 0) {
                msg += ` ${JSON.stringify(rest)}`;
              }
            }
            
            return msg;
          })
        ),
      }),
    ],
  });

  return logger;
}

// Export a singleton logger instance
export const logger = createLogger();
