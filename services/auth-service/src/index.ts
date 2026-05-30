// src/index.ts
import 'dotenv/config';
import express from 'express';
import cors from 'cors';

import { connectDB, disconnectDB } from './db';
import { initFirebase } from './services/firebase.service';

import {
  // Email
  handleEmailSignup,
  handleEmailLogin,
  // Phone
  handlePhoneSignupSendOtp,
  handlePhoneSignupVerify,
  handlePhoneLoginSendOtp,
  handlePhoneLoginVerify,
  // Common
  handleRefresh,
  handleMe,
  handleCheckUsername,
  handleCheckEmail,
  handleCheckPhone,
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
app.get('/', (_req, res) => res.json({ success: true, service: 'auth-service', status: 'running' }));
app.get('/health', (_req, res) => res.json({ ok: true, service: 'auth-service', timestamp: new Date().toISOString() }));

// ─────────────────────────────────────────────────────────────────────────────
// Email Auth
// ─────────────────────────────────────────────────────────────────────────────
app.post('/auth/signup',       handleEmailSignup);   // register with email+password
app.post('/auth/login',        handleEmailLogin);    // login  with email+password

// ─────────────────────────────────────────────────────────────────────────────
// Phone Auth
// ─────────────────────────────────────────────────────────────────────────────
app.post('/auth/signup/phone',          handlePhoneSignupSendOtp);  // Step 1 – send OTP
app.post('/auth/signup/phone/verify',   handlePhoneSignupVerify);   // Step 2 – verify & create
app.post('/auth/login/phone',           handlePhoneLoginSendOtp);   // Step 1 – send OTP
app.post('/auth/login/phone/verify',    handlePhoneLoginVerify);    // Step 2 – verify & login

// ─────────────────────────────────────────────────────────────────────────────
// Token & Profile
// ─────────────────────────────────────────────────────────────────────────────
app.post('/auth/refresh',          handleRefresh);
app.get('/auth/me', requireAuth,   handleMe);

// ─────────────────────────────────────────────────────────────────────────────
// Availability Checks
// ─────────────────────────────────────────────────────────────────────────────
app.post('/auth/check-username',   handleCheckUsername);
app.post('/auth/check-email',      handleCheckEmail);
app.post('/auth/check-phone',      handleCheckPhone);

// ─────────────────────────────────────────────────────────────────────────────
// Error Handlers
// ─────────────────────────────────────────────────────────────────────────────
app.use((_req, res) => res.status(404).json({ success: false, message: 'Route not found' }));
app.use((err: any, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error('[auth-service]', err);
  res.status(err.status || 500).json({ success: false, message: err.message || 'Internal Server Error' });
});

// ─────────────────────────────────────────────────────────────────────────────
// Start
// ─────────────────────────────────────────────────────────────────────────────
async function start() {
  try {
    await connectDB();
    initFirebase();
    app.listen(PORT, () => console.log(`[auth-service] Running on http://localhost:${PORT}`));
  } catch (err) {
    console.error('[auth-service] Startup failed:', err);
    process.exit(1);
  }
}

start();
process.on('SIGTERM', async () => { await disconnectDB(); process.exit(0); });
process.on('SIGINT',  async () => { await disconnectDB(); process.exit(0); });
