import winston from 'winston';
import { config } from '../config';

const { combine, timestamp, colorize, printf, json } = winston.format;

const devFormat = combine(
  colorize(),
  timestamp({ format: 'HH:mm:ss' }),
  printf(({ level, message, timestamp, ...meta }) => {
    const extra = Object.keys(meta).length ? ' ' + JSON.stringify(meta) : '';
    return `[${timestamp}] ${level}: ${message}${extra}`;
  })
);

export const logger = winston.createLogger({
  level: config.isDev ? 'debug' : 'info',
  format: config.isDev ? devFormat : combine(timestamp(), json()),
  transports: [new winston.transports.Console()],
});
