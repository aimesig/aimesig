import { createProxyMiddleware, Options } from 'http-proxy-middleware';
import { Request } from 'express';
import { logger } from './logger';

export function makeProxy(target: string, pathPrefix: string, options?: Partial<Options>) {
  return createProxyMiddleware({
    target,
    changeOrigin: true,
    pathRewrite: { [`^${pathPrefix}`]: '' },

    on: {
      error: (err, req, res) => {
        logger.error('Proxy error', {
          target,
          path: (req as Request).path,
          error: (err as Error).message,
        });
        const r = res as any;
        if (r && !r.headersSent) {
          r.status(502).json({
            error: 'Bad gateway — upstream service unavailable',
            service: pathPrefix.replace('/', ''),
          });
        }
      },

      proxyReq: (proxyReq, req) => {
        const r = req as Request;
        if (r.requestId)   proxyReq.setHeader('X-Request-ID',  r.requestId);
        if (r.user?.sub)   proxyReq.setHeader('X-User-ID',     r.user.sub);
        if (r.user?.email) proxyReq.setHeader('X-User-Email',  r.user.email);
        if (r.user?.role)  proxyReq.setHeader('X-User-Role',   r.user.role);
        proxyReq.removeHeader('Authorization');
      },
    },

    ...options,
  });
}
