// src/controllers/auth.controller.ts
import { Request, Response } from 'express';
import { User } from '../models/user.model';
import { verifyFirebaseToken } from '../services/firebase.service';
import {
  signAccessToken,
  signRefreshToken,
  verifyRefreshToken,
} from '../services/jwt.service';

// ─────────────────────────────────────────────────────────────────────────────
// POST /auth/login
//
// Frontend flow:
//   1. User enters phone number
//   2. Firebase client SDK sends OTP SMS (free)
//   3. User enters code → Firebase returns idToken
//   4. Frontend POSTs idToken (+ username for new users) to this endpoint
//
// Body: { idToken: string, username?: string }
// ─────────────────────────────────────────────────────────────────────────────
export async function handleLogin(req: Request, res: Response) {
  try {
    const { idToken, username } = req.body;

    if (!idToken) {
      return res.status(400).json({ error: 'idToken is required' });
    }

    // Verify with Firebase Admin — throws if invalid/expired
    const { phone, uid } = await verifyFirebaseToken(idToken);

    let user = await User.findOne({ phone });

    if (!user) {
      // ── New user registration ─────────────────────────────────────────────
      if (!username) {
        return res.status(400).json({
          error: 'username is required for new users',
          newUser: true,
        });
      }

      const clean = username.toLowerCase().trim();
      if (!/^[a-z0-9_]{3,30}$/.test(clean)) {
        return res.status(400).json({
          error: 'Username must be 3–30 chars, letters/numbers/underscores only',
        });
      }

      const taken = await User.findOne({ username: clean });
      if (taken) {
        return res.status(409).json({ error: 'Username already taken' });
      }

      user = await User.create({
        phone,
        username:    clean,
        firebaseUid: uid,
        isVerified:  true,
      });

      console.log(`[auth] New user registered: ${user.email}`);
    } else {
      // ── Returning user — update firebaseUid if changed ────────────────────
      if (user.firebaseUid !== uid) {
        user = { ...user, firebaseUid: uid, isVerified: true };
      } else {
        user = { ...user, isVerified: true };
      }
      user = await User.save(user);
    }

    const payload = {
      userId:   user.id,          // Prisma uses `id` (cuid), not `_id`
      username: user.username,
      phone:    user.phone,
      role:     user.role.toLowerCase() as 'user' | 'admin',
      tenantId: user.tenantId ?? null,
    };

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
      },
    });
  } catch (err: any) {
    console.error('[login]', err.message);

    if (err.code?.startsWith('auth/')) {
      return res.status(401).json({ error: 'Invalid or expired Firebase token' });
    }

    return res.status(500).json({ error: 'Login failed' });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /auth/refresh
// Body: { refreshToken: string }
// ─────────────────────────────────────────────────────────────────────────────
export async function handleRefresh(req: Request, res: Response) {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) {
      return res.status(400).json({ error: 'refreshToken required' });
    }

    const payload = verifyRefreshToken(refreshToken);
    const user    = await User.findById(payload.userId);
    if (!user) return res.status(401).json({ error: 'User not found' });

    const newPayload = {
      userId:   user.id,
      username: user.username,
      phone:    user.phone,
      role:     user.role.toLowerCase() as 'user' | 'admin',
      tenantId: user.tenantId ?? null,
    };

    return res.json({ accessToken: signAccessToken(newPayload) });
  } catch {
    return res.status(401).json({ error: 'Invalid or expired refresh token' });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GET /auth/me   (protected — requires Authorization: Bearer <accessToken>)
// ─────────────────────────────────────────────────────────────────────────────
export async function handleMe(req: Request, res: Response) {
  try {
    const userId = (req as any).user?.userId;
    const user   = await User.findById(userId);
    if (!user) return res.status(404).json({ error: 'User not found' });

    // Return user without sensitive fields
    const { firebaseUid: _fbu, ...safeUser } = user;
    return res.json({ user: safeUser });
  } catch {
    return res.status(500).json({ error: 'Failed to fetch profile' });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /auth/check-username
// Body: { username: string }
// ─────────────────────────────────────────────────────────────────────────────
export async function handleCheckUsername(req: Request, res: Response) {
  const { username } = req.body;
  if (!username) return res.status(400).json({ error: 'username required' });

  const clean = username.toLowerCase().trim();
  const taken = await User.findOne({ username: clean });
  return res.json({ available: !taken, username: clean });
}
