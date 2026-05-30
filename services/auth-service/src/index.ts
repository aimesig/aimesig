// src/index.ts
import 'dotenv/config';
import express from 'express';
import cors from 'cors';

import { connectDB, disconnectDB } from './db';
import { initFirebase } from './services/firebase.service';

import {
  handleSignup,
  handleEmailLogin,
  handlePhoneLogin,
  handleRefresh,
  handleMe,
  handleCheckUsername,
  handleCheckEmail,
} from './controllers/auth.controller';

import { requireAuth } from './middleware/auth.middleware';

const app = express();
const PORT = process.env.AUTH_SERVICE_PORT || 4001;

// ─────────────────────────────────────────────────────────────────────────────
// Middleware
// ─────────────────────────────────────────────────────────────────────────────

app.use(cors({ origin: '*', credentials: true }));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ─────────────────────────────────────────────────────────────────────────────
// Health
// ─────────────────────────────────────────────────────────────────────────────

app.get('/', (_req, res) => {
  res.status(200).json({
    success: true,
    service: 'auth-service',
    status:  'running',
    environment: process.env.NODE_ENV || 'development',
  });
});

app.get('/health', (_req, res) => {
  res.status(200).json({ ok: true, service: 'auth-service', timestamp: new Date().toISOString() });
});

// ─────────────────────────────────────────────────────────────────────────────
// Auth Routes
// ─────────────────────────────────────────────────────────────────────────────

// Email + password signup
app.post('/auth/signup', handleSignup);

// Email + password login
app.post('/auth/login', handleEmailLogin);

// Firebase phone OTP → JWT  (kept for phone auth flow)
app.post('/auth/login/phone', handlePhoneLogin);

// Token refresh
app.post('/auth/refresh', handleRefresh);

// Check availability
app.post('/auth/check-username', handleCheckUsername);
app.post('/auth/check-email', handleCheckEmail);

// Authenticated user profile
app.get('/auth/me', requireAuth, handleMe);

// ─────────────────────────────────────────────────────────────────────────────
// 404 / Error Handlers
// ─────────────────────────────────────────────────────────────────────────────

app.use((_req, res) => {
  res.status(404).json({ success: false, message: 'Route not found' });
});

app.use((err: any, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error('[auth-service] Error:', err);
  return res.status(err.status || 500).json({
    success: false,
    message: err.message || 'Internal Server Error',
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// Start
// ─────────────────────────────────────────────────────────────────────────────

async function start() {
  try {
    await connectDB();
    initFirebase();
    app.listen(PORT, () => {
      console.log(`[auth-service] Running on http://localhost:${PORT}`);
    });
  } catch (err) {
    console.error('[auth-service] Startup failed:', err);
    process.exit(1);
  }
}

start();

process.on('SIGTERM', async () => { await disconnectDB(); process.exit(0); });
process.on('SIGINT',  async () => { await disconnectDB(); process.exit(0); });
