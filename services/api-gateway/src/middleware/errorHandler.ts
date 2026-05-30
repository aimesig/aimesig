import { Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger';
import { config } from '../config';

export interface ApiError extends Error {
  statusCode?: number;
}

export function notFound(req: Request, res: Response): void {
  res.status(404).json({
    error: `Route ${req.method} ${req.originalUrl} not found`,
    requestId: req.requestId,
  });
}

export function errorHandler(
  err: ApiError,
  req: Request,
  res: Response,
  _next: NextFunction
): void {
  const status = err.statusCode ?? 500;
  logger.error('Unhandled error', {
    id:      req.requestId,
    status,
    message: err.message,
    stack:   config.isDev ? err.stack : undefined,
  });

  res.status(status).json({
    error:     status >= 500 ? 'Internal server error' : err.message,
    requestId: req.requestId,
    ...(config.isDev && { stack: err.stack }),
  });
}
