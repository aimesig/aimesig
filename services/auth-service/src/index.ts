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

const app  = express();
const PORT = process.env.AUTH_SERVICE_PORT ?? 4001;

app.use(cors());
app.use(express.json());

// ── Routes ───────────────────────────────────────────────────────────────────
app.post('/auth/login',           handleLogin);           // Firebase idToken → JWT
app.post('/auth/refresh',         handleRefresh);
app.post('/auth/check-username',  handleCheckUsername);
app.get ('/auth/me',              requireAuth, handleMe);
app.get ('/health', (_req, res) => res.json({ status: 'ok', service: 'auth' }));

// ── Start ────────────────────────────────────────────────────────────────────
async function start() {
  await connectDB();
  initFirebase();
  app.listen(PORT, () => {
    console.log(`[auth-service] Running on http://localhost:${PORT}`);
  });
}

start().catch((err) => {
  console.error('[auth-service] Startup failed:', err);
  process.exit(1);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  await disconnectDB();
  process.exit(0);
});
