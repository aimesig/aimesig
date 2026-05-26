// src/index.ts

import 'dotenv/config';
import express from 'express';
import cors from 'cors';

import { connectDB, disconnectDB } from './db';
import { initFirebase } from './services/firebase.service';

import {
  handleLogin,
  handleRefresh,
  handleMe,
  handleCheckUsername,
} from './controllers/auth.controller';

import { requireAuth } from './middleware/auth.middleware';

const app = express();

const PORT = process.env.AUTH_SERVICE_PORT || 4001;

// ─────────────────────────────────────────────────────────────
// Middleware
// ─────────────────────────────────────────────────────────────

app.use(
  cors({
    origin: '*',
    credentials: true,
  }),
);

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ─────────────────────────────────────────────────────────────
// Health Routes
// ─────────────────────────────────────────────────────────────

app.get('/', (_req, res) => {
  res.status(200).json({
    success: true,
    service: 'auth-service',
    status: 'running',
    environment: process.env.NODE_ENV || 'development',
  });
});

app.get('/health', (_req, res) => {
  res.status(200).json({
    ok: true,
    service: 'auth-service',
    timestamp: new Date().toISOString(),
  });
});

// ─────────────────────────────────────────────────────────────
// Auth Routes
// ─────────────────────────────────────────────────────────────

// Firebase ID Token → JWT
app.post('/auth/login', handleLogin);

// Refresh Access Token
app.post('/auth/refresh', handleRefresh);

// Username Availability
app.post('/auth/check-username', handleCheckUsername);

// Current Logged User
app.get('/auth/me', requireAuth, handleMe);

// ─────────────────────────────────────────────────────────────
// 404 Handler
// ─────────────────────────────────────────────────────────────

app.use((_req, res) => {
  res.status(404).json({
    success: false,
    message: 'Route not found',
  });
});

// ─────────────────────────────────────────────────────────────
// Global Error Handler
// ─────────────────────────────────────────────────────────────

app.use(
  (
    err: any,
    _req: express.Request,
    res: express.Response,
    _next: express.NextFunction,
  ) => {
    console.error('[auth-service] Error:', err);

    return res.status(err.status || 500).json({
      success: false,
      message: err.message || 'Internal Server Error',
    });
  },
);

// ─────────────────────────────────────────────────────────────
// Start Server
// ─────────────────────────────────────────────────────────────

async function start() {
  try {
    await connectDB();

    initFirebase();

    app.listen(PORT, () => {
      console.log(
        `[auth-service] Running on http://localhost:${PORT}`,
      );
    });
  } catch (err) {
    console.error('[auth-service] Startup failed:', err);
    process.exit(1);
  }
}

start();

// ─────────────────────────────────────────────────────────────
// Graceful Shutdown
// ─────────────────────────────────────────────────────────────

process.on('SIGTERM', async () => {
  console.log('[auth-service] SIGTERM received');

  await disconnectDB();

  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('[auth-service] SIGINT received');

  await disconnectDB();

  process.exit(0);
});