// src/services/otp.service.ts
//
// OTP lifecycle: generate → persist in Neon → deliver via WhatsApp.
// Verification: lookup + TTL + attempt-rate check + consume on success.

import { sql } from '../db';
import { sendWhatsAppOtp } from './whatsapp.service';

const OTP_TTL_SECONDS = 300;   // 5 minutes (matches template footer)
const MAX_ATTEMPTS    = 5;

function generateOtp(): string {
  return Math.floor(100_000 + Math.random() * 900_000).toString();
}

// ─────────────────────────────────────────────────────────────────────────────
// sendOtp
// Clears any existing OTP for this phone, generates a fresh 6-digit code,
// persists it, then delivers it via WhatsApp.
// ─────────────────────────────────────────────────────────────────────────────
export async function sendOtp(phone: string): Promise<void> {
  // Remove any previous OTP for this number (one active OTP at a time)
  await sql`DELETE FROM otps WHERE phone = ${phone}`;

  const code = generateOtp();

  await sql`
    INSERT INTO otps (id, phone, code, attempts, created_at)
    VALUES (gen_random_uuid()::text, ${phone}, ${code}, 0, now())
  `;

  // In dev, if Meta creds are missing the service logs the code to console
  // so you can still test without a live WhatsApp number.
  await sendWhatsAppOtp(phone, code);
}

// ─────────────────────────────────────────────────────────────────────────────
// verifyOtp
// Returns { valid: true } on success (and deletes the record).
// Returns { valid: false, reason } on any failure.
// ─────────────────────────────────────────────────────────────────────────────
export async function verifyOtp(
  phone: string,
  code: string,
): Promise<{ valid: boolean; reason?: string }> {
  const rows = await sql`
    SELECT * FROM otps
    WHERE phone = ${phone}
    ORDER BY created_at DESC
    LIMIT 1
  `;
  const record = rows[0];

  if (!record) {
    return { valid: false, reason: 'No OTP found. Please request a new one.' };
  }

  // TTL check
  const expiry = new Date(record.created_at).getTime() + OTP_TTL_SECONDS * 1000;
  if (Date.now() > expiry) {
    await sql`DELETE FROM otps WHERE id = ${record.id}`;
    return { valid: false, reason: 'OTP has expired. Please request a new one.' };
  }

  // Attempt-rate check
  if (record.attempts >= MAX_ATTEMPTS) {
    await sql`DELETE FROM otps WHERE id = ${record.id}`;
    return { valid: false, reason: 'Too many incorrect attempts. Please request a new OTP.' };
  }

  // Code check
  if (record.code !== code.trim()) {
    await sql`UPDATE otps SET attempts = attempts + 1 WHERE id = ${record.id}`;
    const left = MAX_ATTEMPTS - (record.attempts + 1);
    return { valid: false, reason: `Invalid OTP. ${left} attempt${left === 1 ? '' : 's'} remaining.` };
  }

  // ✓ Valid — consume
  await sql`DELETE FROM otps WHERE id = ${record.id}`;
  return { valid: true };
}
