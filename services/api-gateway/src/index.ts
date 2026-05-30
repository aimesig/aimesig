import express, { Request, Response } from 'express';
import cors, { CorsOptions } from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';

import { config } from './config';
import { logger } from './utils/logger';
import { checkDbConnection, sql } from './utils/db';
import { requestId, accessLog } from './middleware/requestId';
import { notFound, errorHandler } from './middleware/errorHandler';

import authRoutes     from './routes/auth';
import chatRoutes     from './routes/chat';
import erpRoutes      from './routes/erp';
import hrmsRoutes     from './routes/hrms';
import websitesRoutes from './routes/websites';

const app = express();

const corsOptions: CorsOptions = {
  origin: (origin: string | undefined, cb: (err: Error | null, allow?: boolean) => void) => {
    if (!origin || config.cors.origins.includes(origin)) return cb(null, true);
    cb(new Error(`CORS blocked: ${origin}`));
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Request-ID'],
  exposedHeaders: ['X-Request-ID'],
};

app.use(helmet());
app.use(cors(corsOptions));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(requestId);
app.use(accessLog);
app.use(rateLimit({
  windowMs: config.rateLimit.windowMs,
  max:      config.rateLimit.max,
  standardHeaders: true,
  legacyHeaders:   false,
  message: { error: 'Too many requests, please try again later.' },
}));

app.get('/health', async (_req: Request, res: Response) => {
  try {
    await sql`SELECT 1`;
    res.json({ status: 'ok', service: 'api-gateway', db: 'neon:connected', ts: new Date().toISOString() });
  } catch {
    res.status(503).json({ status: 'degraded', db: 'neon:unreachable', ts: new Date().toISOString() });
  }
});

app.use('/auth',     authRoutes);
app.use('/chat',     chatRoutes);
app.use('/erp',      erpRoutes);
app.use('/hrms',     hrmsRoutes);
app.use('/websites', websitesRoutes);

app.use(notFound);
app.use(errorHandler);

async function bootstrap() {
  await checkDbConnection();
  const server = app.listen(config.port, () => {
    logger.info(`api.aimesig.com gateway :${config.port}`, { env: config.nodeEnv });
  });

  const shutdown = (signal: string) => {
    logger.info(`${signal} — graceful shutdown`);
    server.close(() => { logger.info('closed'); process.exit(0); });
    setTimeout(() => process.exit(1), 10_000);
  };
  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT',  () => shutdown('SIGINT'));
}

bootstrap().catch((err: Error) => {
  logger.error('Failed to start', { error: err.message });
  process.exit(1);
});

export default app;
