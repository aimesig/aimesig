// src/controllers/auth.controller.ts
import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import { User } from '../models/user.model';
import {
  createFirebaseEmailUser,
  deleteFirebaseUser,
  verifyFirebaseToken,
} from '../services/firebase.service';
import { sendOtp, verifyOtp } from '../services/otp.service';
import {
  signAccessToken,
  signRefreshToken,
  verifyRefreshToken,
} from '../services/jwt.service';

// ─────────────────────────────────────────────────────────────────────────────
// Constants & helpers
// ─────────────────────────────────────────────────────────────────────────────

const USERNAME_RE = /^[a-z0-9_]{3,30}$/;
const EMAIL_RE    = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
// E.164: +<country><number>, 7–15 digits after the +
const PHONE_RE    = /^\+[1-9]\d{6,14}$/;
const MIN_PW_LEN  = 8;

function buildPayload(user: {
  id: string; username: string; phone: string | null;
  role: string; tenantId: string | null;
}) {
  return {
    userId:   user.id,
    username: user.username,
    phone:    user.phone ?? '',
    role:     user.role.toLowerCase() as 'user' | 'admin',
    tenantId: user.tenantId ?? null,
  };
}

function publicUser(user: {
  id: string; username: string; email: string;
  displayName: string | null; avatar: string | null;
  role: string; isVerified: boolean;
}) {
  return {
    id:          user.id,
    username:    user.username,
    email:       user.email,
    displayName: user.displayName,
    avatar:      user.avatar,
    role:        user.role,
    isVerified:  user.isVerified,
  };
}

function issueTokens(user: Parameters<typeof buildPayload>[0]) {
  const payload = buildPayload(user);
  return {
    accessToken:  signAccessToken(payload),
    refreshToken: signRefreshToken(payload),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// EMAIL SIGNUP
// POST /auth/signup
// Body: { email, password, username, displayName? }
// ─────────────────────────────────────────────────────────────────────────────
export async function handleEmailSignup(req: Request, res: Response) {
  const { email, password, username, displayName } = req.body;

  if (!email || !password || !username) {
    return res.status(400).json({ error: 'email, password, and username are required' });
  }
  if (!EMAIL_RE.test(email.trim())) {
    return res.status(400).json({ error: 'Invalid email address' });
  }
  if (password.length < MIN_PW_LEN) {
    return res.status(400).json({ error: `Password must be at least ${MIN_PW_LEN} characters` });
  }
  const cleanUsername = username.toLowerCase().trim();
  if (!USERNAME_RE.test(cleanUsername)) {
    return res.status(400).json({
      error: 'Username must be 3–30 characters: letters, numbers, and underscores only',
    });
  }

  const cleanEmail = email.toLowerCase().trim();

  try {
    const [byEmail, byUsername] = await Promise.all([
      User.findOne({ email: cleanEmail }),
      User.findOne({ username: cleanUsername }),
    ]);
    if (byEmail)     return res.status(409).json({ error: 'An account with this email already exists' });
    if (byUsername)  return res.status(409).json({ error: 'Username is already taken' });

    // Create in Firebase Auth first (stores email+password there too)
    const firebaseUid = await createFirebaseEmailUser(
      cleanEmail, password, displayName?.trim() || cleanUsername,
    );

    const passwordHash = await bcrypt.hash(password, 12);

    let user;
    try {
      user = await User.create({
        email:        cleanEmail,
        username:     cleanUsername,
        passwordHash,
        firebaseUid,
        displayName:  displayName?.trim() || null,
        isVerified:   false,
        authProvider: 'EMAIL',
      });
    } catch (dbErr) {
      await deleteFirebaseUser(firebaseUid).catch(() => {});
      throw dbErr;
    }

    console.log(`[auth] Email signup: ${user.email} (${user.id})`);
    const tokens = issueTokens(user);
    return res.status(201).json({ ...tokens, user: publicUser(user) });

  } catch (err: any) {
    console.error('[email-signup]', err.message);
    if (err.code === 'auth/email-already-exists') return res.status(409).json({ error: 'Email already registered' });
    if (err.code === 'auth/weak-password')         return res.status(400).json({ error: 'Password is too weak' });
    return res.status(500).json({ error: 'Signup failed. Please try again.' });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMAIL LOGIN
// POST /auth/login
// Body: { email, password }
// ─────────────────────────────────────────────────────────────────────────────
export async function handleEmailLogin(req: Request, res: Response) {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ error: 'email and password are required' });
  }

  try {
    const user = await User.findOne({ email: email.toLowerCase().trim() });

    if (!user || !user.passwordHash) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }
    if (user.authProvider !== 'EMAIL') {
      return res.status(400).json({
        error: `This account was created with ${user.authProvider.toLowerCase()} sign-in. Please use that method.`,
      });
    }

    const match = await bcrypt.compare(password, user.passwordHash);
    if (!match) return res.status(401).json({ error: 'Invalid email or password' });

    const tokens = issueTokens(user);
    return res.json({ ...tokens, user: publicUser(user) });

  } catch (err: any) {
    console.error('[email-login]', err.message);
    return res.status(500).json({ error: 'Login failed. Please try again.' });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PHONE SIGNUP — Step 1: Send OTP
// POST /auth/signup/phone
// Body: { phone, username, displayName? }
//
// Validates phone + username availability, then sends OTP.
// Username is passed here so the user doesn't have to re-enter it on verify.
// ─────────────────────────────────────────────────────────────────────────────
export async function handlePhoneSignupSendOtp(req: Request, res: Response) {
  const { phone, username, displayName } = req.body;

  if (!phone || !username) {
    return res.status(400).json({ error: 'phone and username are required' });
  }
  if (!PHONE_RE.test(phone.trim())) {
    return res.status(400).json({ error: 'Phone must be in E.164 format, e.g. +919876543210' });
  }

  const cleanPhone    = phone.trim();
  const cleanUsername = username.toLowerCase().trim();
  if (!USERNAME_RE.test(cleanUsername)) {
    return res.status(400).json({
      error: 'Username must be 3–30 characters: letters, numbers, and underscores only',
    });
  }

  try {
    const [byPhone, byUsername] = await Promise.all([
      User.findOne({ phone: cleanPhone }),
      User.findOne({ username: cleanUsername }),
    ]);
    if (byPhone)    return res.status(409).json({ error: 'An account with this phone number already exists' });
    if (byUsername) return res.status(409).json({ error: 'Username is already taken' });

    await sendOtp(cleanPhone);

    return res.json({
      message: 'OTP sent successfully',
      phone:   cleanPhone,
      // Echo back so client can pass in verify step without storing state
      username:    cleanUsername,
      displayName: displayName?.trim() || null,
    });
  } catch (err: any) {
    console.error('[phone-signup-otp]', err.message);
    return res.status(500).json({ error: 'Failed to send OTP. Please try again.' });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PHONE SIGNUP — Step 2: Verify OTP & Create Account
// POST /auth/signup/phone/verify
// Body: { phone, otp, username, displayName? }
// ─────────────────────────────────────────────────────────────────────────────
export async function handlePhoneSignupVerify(req: Request, res: Response) {
  const { phone, otp, username, displayName } = req.body;

  if (!phone || !otp || !username) {
    return res.status(400).json({ error: 'phone, otp, and username are required' });
  }

  const cleanPhone    = phone.trim();
  const cleanUsername = username.toLowerCase().trim();

  try {
    // ── Verify OTP ────────────────────────────────────────────────────────────
    const result = await verifyOtp(cleanPhone, otp.trim());
    if (!result.valid) {
      return res.status(400).json({ error: result.reason });
    }

    // ── Final uniqueness check (race condition guard) ─────────────────────────
    const [byPhone, byUsername] = await Promise.all([
      User.findOne({ phone: cleanPhone }),
      User.findOne({ username: cleanUsername }),
    ]);
    if (byPhone)    return res.status(409).json({ error: 'An account with this phone number already exists' });
    if (byUsername) return res.status(409).json({ error: 'Username is already taken' });

    // Auto-generate email for phone-only users
    const autoEmail = `${cleanUsername}@aimesig.com`;

    const user = await User.create({
      phone:        cleanPhone,
      username:     cleanUsername,
      email:        autoEmail,
      displayName:  displayName?.trim() || null,
      isVerified:   true,   // OTP verified = phone verified
      authProvider: 'PHONE',
    });

    console.log(`[auth] Phone signup: ${user.phone} → ${user.username} (${user.id})`);
    const tokens = issueTokens(user);
    return res.status(201).json({ ...tokens, user: publicUser(user) });

  } catch (err: any) {
    console.error('[phone-signup-verify]', err.message);
    return res.status(500).json({ error: 'Signup failed. Please try again.' });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PHONE LOGIN — Step 1: Send OTP
// POST /auth/login/phone
// Body: { phone }
// ─────────────────────────────────────────────────────────────────────────────
export async function handlePhoneLoginSendOtp(req: Request, res: Response) {
  const { phone } = req.body;

  if (!phone) {
    return res.status(400).json({ error: 'phone is required' });
  }
  if (!PHONE_RE.test(phone.trim())) {
    return res.status(400).json({ error: 'Phone must be in E.164 format, e.g. +919876543210' });
  }

  const cleanPhone = phone.trim();

  try {
    const user = await User.findOne({ phone: cleanPhone });
    if (!user) {
      // Don't reveal whether the account exists
      return res.status(404).json({ error: 'No account found with this phone number' });
    }
    if (user.authProvider !== 'PHONE') {
      return res.status(400).json({
        error: `This account uses ${user.authProvider.toLowerCase()} sign-in. Please use that method.`,
      });
    }

    await sendOtp(cleanPhone);
    return res.json({ message: 'OTP sent successfully', phone: cleanPhone });

  } catch (err: any) {
    console.error('[phone-login-otp]', err.message);
    return res.status(500).json({ error: 'Failed to send OTP. Please try again.' });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PHONE LOGIN — Step 2: Verify OTP & Issue Tokens
// POST /auth/login/phone/verify
// Body: { phone, otp }
// ─────────────────────────────────────────────────────────────────────────────
export async function handlePhoneLoginVerify(req: Request, res: Response) {
  const { phone, otp } = req.body;

  if (!phone || !otp) {
    return res.status(400).json({ error: 'phone and otp are required' });
  }

  const cleanPhone = phone.trim();

  try {
    const result = await verifyOtp(cleanPhone, otp.trim());
    if (!result.valid) {
      return res.status(400).json({ error: result.reason });
    }

    const user = await User.findOne({ phone: cleanPhone });
    if (!user) return res.status(404).json({ error: 'Account not found' });

    const tokens = issueTokens(user);
    return res.json({ ...tokens, user: publicUser(user) });

  } catch (err: any) {
    console.error('[phone-login-verify]', err.message);
    return res.status(500).json({ error: 'Login failed. Please try again.' });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOKEN REFRESH
// POST /auth/refresh
// Body: { refreshToken }
// ─────────────────────────────────────────────────────────────────────────────
export async function handleRefresh(req: Request, res: Response) {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) return res.status(400).json({ error: 'refreshToken is required' });

    const payload = verifyRefreshToken(refreshToken);
    const user    = await User.findById(payload.userId);
    if (!user) return res.status(401).json({ error: 'User not found' });

    return res.json({ accessToken: signAccessToken(buildPayload(user)) });
  } catch {
    return res.status(401).json({ error: 'Invalid or expired refresh token' });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GET /auth/me  (protected)
// ─────────────────────────────────────────────────────────────────────────────
export async function handleMe(req: Request, res: Response) {
  try {
    const userId = (req as any).user?.userId;
    const user   = await User.findById(userId);
    if (!user) return res.status(404).json({ error: 'User not found' });

    const { passwordHash: _pw, firebaseUid: _fb, ...safeFields } = user;
    return res.json({ user: safeFields });
  } catch {
    return res.status(500).json({ error: 'Failed to fetch profile' });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /auth/check-username  |  Body: { username }
// ─────────────────────────────────────────────────────────────────────────────
export async function handleCheckUsername(req: Request, res: Response) {
  const { username } = req.body;
  if (!username) return res.status(400).json({ error: 'username is required' });

  const clean = username.toLowerCase().trim();
  if (!USERNAME_RE.test(clean)) {
    return res.status(400).json({ error: 'Invalid username format', available: false });
  }
  const taken = await User.findOne({ username: clean });
  return res.json({ available: !taken, username: clean });
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /auth/check-email  |  Body: { email }
// ─────────────────────────────────────────────────────────────────────────────
export async function handleCheckEmail(req: Request, res: Response) {
  const { email } = req.body;
  if (!email) return res.status(400).json({ error: 'email is required' });

  const clean = email.toLowerCase().trim();
  if (!EMAIL_RE.test(clean)) {
    return res.status(400).json({ error: 'Invalid email address', available: false });
  }
  const taken = await User.findOne({ email: clean });
  return res.json({ available: !taken, email: clean });
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /auth/check-phone  |  Body: { phone }
// ─────────────────────────────────────────────────────────────────────────────
export async function handleCheckPhone(req: Request, res: Response) {
  const { phone } = req.body;
  if (!phone) return res.status(400).json({ error: 'phone is required' });

  const clean = phone.trim();
  if (!PHONE_RE.test(clean)) {
    return res.status(400).json({ error: 'Phone must be in E.164 format', available: false });
  }
  const taken = await User.findOne({ phone: clean });
  return res.json({ available: !taken, phone: clean });
}
