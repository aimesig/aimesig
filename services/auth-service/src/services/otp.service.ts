// src/services/otp.service.ts
import axios from 'axios';
import { sql } from '../db';

const OTP_TTL_SECONDS = 300;

function generateOtp() {
  return Math.floor(100_000 + Math.random() * 900_000).toString();
}

async function sendViaMSG91(phone: string, code: string) {
  const { MSG91_AUTH_KEY, MSG91_TEMPLATE_ID } = process.env;
  if (!MSG91_AUTH_KEY || !MSG91_TEMPLATE_ID) {
    console.log(`[OTP] Phone: ${phone}  Code: ${code}`);
    return;
  }
  await axios.post('https://control.msg91.com/api/v5/otp',
    { template_id: MSG91_TEMPLATE_ID, mobile: phone.replace('+', ''), otp: code },
    { headers: { authkey: MSG91_AUTH_KEY } }
  );
}

export async function sendOtp(phone: string): Promise<void> {
  await sql`DELETE FROM otps WHERE phone = ${phone}`;
  const code = generateOtp();
  await sql`INSERT INTO otps (id, phone, code) VALUES (gen_random_uuid()::text, ${phone}, ${code})`;
  await sendViaMSG91(phone, code);
}

export async function verifyOtp(phone: string, code: string) {
  const rows = await sql`
    SELECT * FROM otps WHERE phone = ${phone}
    ORDER BY created_at DESC LIMIT 1`;
  const record = rows[0];
  const ttl = new Date(Date.now() - OTP_TTL_SECONDS * 1000);

  if (!record || record.created_at < ttl) {
    if (record) await sql`DELETE FROM otps WHERE id = ${record.id}`;
    return { valid: false, reason: 'OTP expired or not found' };
  }
  if (record.attempts >= 5) {
    await sql`DELETE FROM otps WHERE id = ${record.id}`;
    return { valid: false, reason: 'Too many attempts. Request a new OTP.' };
  }
  if (record.code !== code) {
    await sql`UPDATE otps SET attempts = attempts + 1 WHERE id = ${record.id}`;
    return { valid: false, reason: 'Invalid OTP' };
  }
  await sql`DELETE FROM otps WHERE id = ${record.id}`;
  return { valid: true };
}