// Firebase Admin — verifies the idToken sent from frontend after phone OTP
// The frontend (web/mobile) handles sending the OTP via Firebase client SDK.
// Backend only needs to verify the resulting idToken.

import admin from 'firebase-admin';
import path from 'path';

let initialized = false;

export function initFirebase() {
  if (initialized) return;

  const serviceAccountPath =
    process.env.FIREBASE_SERVICE_ACCOUNT_PATH ??
    path.resolve(process.cwd(), 'firebase-service-account.json');

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccountPath),
  });

  initialized = true;
  console.log('[Firebase] Admin SDK initialized');
}

// Verify the idToken the client sends after completing phone OTP
export async function verifyFirebaseToken(
  idToken: string
): Promise<{ phone: string; uid: string }> {
  const decoded = await admin.auth().verifyIdToken(idToken);

  if (!decoded.phone_number) {
    throw new Error('Token does not contain a phone number');
  }

  return {
    phone: decoded.phone_number,
    uid:   decoded.uid,
  };
}
