// apps/web/src/lib/firebase.ts
// Firebase CLIENT SDK — runs in browser, sends OTP, returns idToken
// All values are public/safe to expose in frontend

import { initializeApp, getApps } from 'firebase/app';
import {
  getAuth,
  RecaptchaVerifier,
  signInWithPhoneNumber,
  ConfirmationResult,
} from 'firebase/auth';

const firebaseConfig = {
  apiKey:            process.env.NEXT_PUBLIC_FIREBASE_API_KEY!,
  authDomain:        process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN!,
  projectId:         process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID!,
  storageBucket:     process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET!,
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID!,
  appId:             process.env.NEXT_PUBLIC_FIREBASE_APP_ID!,
};

// Prevent re-initializing on hot reload
const app  = getApps().length ? getApps()[0] : initializeApp(firebaseConfig);
export const auth = getAuth(app);

// ── Step 1: Send OTP ─────────────────────────────────────────────────────────
// Call this on "Send OTP" button click.
// buttonId = id of the button element (used as invisible reCAPTCHA anchor)
export async function sendPhoneOtp(
  phone: string,               // e.g. "+919876543210"
  buttonId: string             // DOM element id for reCAPTCHA
): Promise<ConfirmationResult> {
  const verifier = new RecaptchaVerifier(auth, buttonId, {
    size: 'invisible',         // invisible reCAPTCHA — no UI friction
  });

  const confirmation = await signInWithPhoneNumber(auth, phone, verifier);
  return confirmation;
}

// ── Step 2: Verify OTP and get idToken ───────────────────────────────────────
// Pass the ConfirmationResult from step 1 and the code user typed.
// Returns the idToken to send to your backend /auth/login
export async function confirmOtp(
  confirmation: ConfirmationResult,
  code: string
): Promise<string> {
  const result  = await confirmation.confirm(code);
  const idToken = await result.user.getIdToken();
  return idToken;
}
