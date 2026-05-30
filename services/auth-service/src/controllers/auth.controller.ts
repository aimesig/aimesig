// src/controllers/auth.controller.ts
import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import { User } from '../models/user.model';
import {
  verifyFirebaseToken,
  createFirebaseEmailUser,
  deleteFirebaseUser,
} from '../services/firebase.service';
import {
  signAccessToken,
  signRefreshToken,
  verifyRefreshToken,
} from '../services/jwt.service';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

const USERNAME_RE = /^[a-z0-9_]{3,30}$/;
const EMAIL_RE    = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const MIN_PW_LEN  = 8;

function buildTokenPayload(user: { id: string; username: string; phone: string | null; role: string; tenantId: string | null }) {
  return {
    userId:   user.id,
    username: user.username,
    phone:    user.phone ?? '',
    role:     user.role.toLowerCase() as 'user' | 'admin',
    tenantId: user.tenantId ?? null,
  };
}

function safeUser(user: ReturnType<typeof buildTokenPayload> & {
  id: string; email: string; displayName: string | null; avatar: string | null; role: string;
}) {
  return {
    id:          user.id,
    username:    user.username,
    email:       user.email,
    displayName: user.displayName,
    avatar:      user.avatar,
    role:        user.role,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /auth/signup
//
// Email + password registration.
// 1. Validates input
// 2. Creates Firebase Auth user (stores password there too)
// 3. Inserts row in Neon with bcrypt hash
// Rollback: if Neon insert fails, Firebase user is deleted.
//
// Body: { email, password, username, displayName? }
// ─────────────────────────────────────────────────────────────────────────────
export async function handleSignup(req: Request, res: Response) {
  const { email, password, username, displayName } = req.body;

  // ── Validation ─────────────────────────────────────────────────────────────
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
    // ── Check uniqueness ──────────────────────────────────────────────────────
    const [existingEmail, existingUsername] = await Promise.all([
      User.findOne({ email: cleanEmail }),
      User.findOne({ username: cleanUsername }),
    ]);

    if (existingEmail) {
      return res.status(409).json({ error: 'An account with this email already exists' });
    }
    if (existingUsername) {
      return res.status(409).json({ error: 'Username is already taken' });
    }

    // ── Create Firebase Auth user ─────────────────────────────────────────────
    const firebaseUid = await createFirebaseEmailUser(
      cleanEmail,
      password,
      displayName?.trim() || cleanUsername,
    );

    // ── Hash password for Neon ────────────────────────────────────────────────
    const passwordHash = await bcrypt.hash(password, 12);

    let user;
    try {
      user = await User.create({
        email:        cleanEmail,
        username:     cleanUsername,
        passwordHash,
        firebaseUid,
        displayName:  displayName?.trim() || null,
        isVerified:   false,  // email not yet verified
        authProvider: 'EMAIL',
      });
    } catch (dbErr) {
      // Neon insert failed — rollback Firebase user
      console.error('[signup] Neon insert failed, rolling back Firebase user', dbErr);
      await deleteFirebaseUser(firebaseUid).catch(() => {});
      throw dbErr;
    }

    console.log(`[auth] New email signup: ${user.email} (${user.id})`);

    const payload = buildTokenPayload(user);
    const accessToken  = signAccessToken(payload);
    const refreshToken = signRefreshToken(payload);

    return res.status(201).json({
      accessToken,
      refreshToken,
      user: {
        id:          user.id,
        username:    user.username,
        email:       user.email,
        displayName: user.displayName,
        avatar:      user.avatar,
        role:        user.role,
        isVerified:  user.isVerified,
      },
    });
  } catch (err: any) {
    console.error('[signup]', err.message);

    if (err.code === 'auth/email-already-exists') {
      return res.status(409).json({ error: 'An account with this email already exists' });
    }
    if (err.code === 'auth/invalid-email') {
      return res.status(400).json({ error: 'Invalid email address' });
    }
    if (err.code === 'auth/weak-password') {
      return res.status(400).json({ error: 'Password is too weak' });
    }

    return res.status(500).json({ error: 'Signup failed. Please try again.' });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /auth/login  (email + password)
//
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
      // Generic message to avoid user enumeration
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    if (user.authProvider !== 'EMAIL') {
      return res.status(400).json({
        error: `This account uses ${user.authProvider.toLowerCase()} login. Please sign in that way.`,
      });
    }

    const passwordMatch = await bcrypt.compare(password, user.passwordHash);
    if (!passwordMatch) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const payload = buildTokenPayload(user);
    const accessToken  = signAccessToken(payload);
    const refreshToken = signRefreshToken(payload);

    return res.json({
      accessToken,
      refreshToken,
      user: {
        id:          user.id,
        username:    user.username,
        email:       user.email,
        displayName: user.displayName,
        avatar:      user.avatar,
        role:        user.role,
        isVerified:  user.isVerified,
      },
    });
  } catch (err: any) {
    console.error('[email-login]', err.message);
    return res.status(500).json({ error: 'Login failed. Please try again.' });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /auth/login/phone  (Firebase phone OTP → JWT)
//
// Body: { idToken, username? }
// ─────────────────────────────────────────────────────────────────────────────
export async function handlePhoneLogin(req: Request, res: Response) {
  try {
    const { idToken, username } = req.body;

    if (!idToken) {
      return res.status(400).json({ error: 'idToken is required' });
    }

    const decoded = await verifyFirebaseToken(idToken);
    const phone   = decoded.phone_number;
    const uid     = decoded.uid;

    if (!phone) {
      return res.status(400).json({ error: 'Firebase token does not contain a phone number' });
    }

    let user = await User.findOne({ phone });

    if (!user) {
      if (!username) {
        return res.status(400).json({ error: 'username is required for new users', newUser: true });
      }

      const clean = username.toLowerCase().trim();
      if (!USERNAME_RE.test(clean)) {
        return res.status(400).json({
          error: 'Username must be 3–30 characters: letters, numbers, and underscores only',
        });
      }

      const taken = await User.findOne({ username: clean });
      if (taken) {
        return res.status(409).json({ error: 'Username already taken' });
      }

      // Auto-generate a unique email for phone-only users
      const autoEmail = `${clean}@aimesig.com`;

      user = await User.create({
        phone,
        username:     clean,
        email:        autoEmail,
        firebaseUid:  uid,
        isVerified:   true,
        authProvider: 'PHONE',
      });

      console.log(`[auth] New phone user: ${user.username} (${user.id})`);
    } else {
      // Update firebaseUid if rotated
      user = await User.save({
        ...user,
        firebaseUid: uid,
        isVerified:  true,
      });
    }

    const payload = buildTokenPayload(user);
    const accessToken  = signAccessToken(payload);
    const refreshToken = signRefreshToken(payload);

    return res.json({
      accessToken,
      refreshToken,
      user: {
        id:          user.id,
        username:    user.username,
        email:       user.email,
        displayName: user.displayName,
        avatar:      user.avatar,
        role:        user.role,
        isVerified:  user.isVerified,
      },
    });
  } catch (err: any) {
    console.error('[phone-login]', err.message);
    if (err.code?.startsWith('auth/')) {
      return res.status(401).json({ error: 'Invalid or expired Firebase token' });
    }
    return res.status(500).json({ error: 'Login failed. Please try again.' });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /auth/refresh
// Body: { refreshToken }
// ─────────────────────────────────────────────────────────────────────────────
export async function handleRefresh(req: Request, res: Response) {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) {
      return res.status(400).json({ error: 'refreshToken is required' });
    }

    const payload = verifyRefreshToken(refreshToken);
    const user    = await User.findById(payload.userId);
    if (!user) return res.status(401).json({ error: 'User not found' });

    return res.json({ accessToken: signAccessToken(buildTokenPayload(user)) });
  } catch {
    return res.status(401).json({ error: 'Invalid or expired refresh token' });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GET /auth/me   (protected)
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
// POST /auth/check-username
// Body: { username }
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
// POST /auth/check-email
// Body: { email }
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
