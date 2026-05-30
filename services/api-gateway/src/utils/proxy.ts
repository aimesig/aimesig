import { createProxyMiddleware, Options } from 'http-proxy-middleware';
import { Request } from 'express';
import { logger } from '../utils/logger';

/**
 * Creates a reverse-proxy middleware that forwards requests to `target`.
 *
 * @param target  - Upstream base URL, e.g. "http://auth-service:4001"
 * @param pathPrefix - The gateway path prefix to strip, e.g. "/auth"
 * @param options - Any extra http-proxy-middleware options
 */
export function makeProxy(target: string, pathPrefix: string, options?: Partial<Options>) {
  return createProxyMiddleware({
    target,
    changeOrigin: true,
    // Strip the gateway prefix so upstream sees clean paths
    pathRewrite: { [`^${pathPrefix}`]: '' },

    on: {
      error: (err, req, res: any) => {
        logger.error('Proxy error', {
          target,
          path: (req as Request).path,
          error: (err as Error).message,
        });
        if (!res.headersSent) {
          res.status(502).json({
            error: 'Bad gateway — upstream service unavailable',
            service: pathPrefix.replace('/', ''),
          });
        }
      },

      proxyReq: (proxyReq, req) => {
        const r = req as Request;
        if (r.requestId) proxyReq.setHeader('X-Request-ID', r.requestId);
        if (r.user?.sub)   proxyReq.setHeader('X-User-ID',    r.user.sub);
        if (r.user?.email) proxyReq.setHeader('X-User-Email', r.user.email);
        if (r.user?.role)  proxyReq.setHeader('X-User-Role',  r.user.role);
        // Strip Authorization from upstream to avoid leaking secrets
        proxyReq.removeHeader('Authorization');
      },
    },

    ...options,
  });
}
