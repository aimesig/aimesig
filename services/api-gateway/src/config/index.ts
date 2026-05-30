import dotenv from 'dotenv';
dotenv.config();

const opt = (key: string, fallback: string): string =>
  process.env[key] ?? fallback;

const req = (key: string): string => {
  const val = process.env[key];
  if (!val) throw new Error(`Missing required env var: ${key}`);
  return val;
};

export const config = {
  port: parseInt(opt('PORT', '3000'), 10),
  nodeEnv: opt('NODE_ENV', 'development'),
  isDev: opt('NODE_ENV', 'development') === 'development',

  // Neon postgres connection string
  databaseUrl: req('DATABASE_URL'),

  jwt: {
    secret: opt('JWT_SECRET', 'dev-secret-change-in-prod'),
    expiresIn: opt('JWT_EXPIRES_IN', '7d'),
  },

  upstreams: {
    auth:     opt('AUTH_SERVICE_URL',     'http://localhost:4001'),
    chat:     opt('CHAT_SERVICE_URL',     'http://localhost:4002'),
    erp:      opt('ERP_SERVICE_URL',      'http://localhost:4003'),
    hrms:     opt('HRMS_SERVICE_URL',     'http://localhost:4004'),
    websites: opt('WEBSITES_SERVICE_URL', 'http://localhost:4005'),
  },

  rateLimit: {
    windowMs: parseInt(opt('RATE_LIMIT_WINDOW_MS', '60000'), 10),
    max:      parseInt(opt('RATE_LIMIT_MAX',        '200'),   10),
    authMax:  parseInt(opt('AUTH_RATE_LIMIT_MAX',   '20'),    10),
  },

  cors: {
    origins: opt(
      'ALLOWED_ORIGINS',
      'https://app.aimesig.com,https://aimesig.com'
    ).split(','),
  },
};
