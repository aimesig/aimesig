import { Request, Response, NextFunction } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { logger } from '../utils/logger';

/** Attaches a unique X-Request-ID to every request and logs it. */
export function requestId(req: Request, res: Response, next: NextFunction): void {
  const id = (req.headers['x-request-id'] as string) ?? uuidv4();
  req.requestId = id;
  req.headers['x-request-id'] = id;
  res.setHeader('X-Request-ID', id);
  next();
}

/** HTTP access logger — logs method, path, status, and latency. */
export function accessLog(req: Request, res: Response, next: NextFunction): void {
  const start = Date.now();
  res.on('finish', () => {
    logger.info('→', {
      id:      req.requestId,
      method:  req.method,
      path:    req.path,
      status:  res.statusCode,
      ms:      Date.now() - start,
      ip:      req.ip,
    });
  });
  next();
}
