// apps/mobile/src/lib/firebase.ts
// React Native / Expo — uses Firebase JS SDK (not native SDK)

import { initializeApp, getApps } from 'firebase/app';
import {
  getAuth,
  signInWithPhoneNumber,
  ApplicationVerifier,
  ConfirmationResult,
} from 'firebase/auth';

const firebaseConfig = {
  apiKey:            process.env.EXPO_PUBLIC_FIREBASE_API_KEY!,
  authDomain:        process.env.EXPO_PUBLIC_FIREBASE_AUTH_DOMAIN!,
  projectId:         process.env.EXPO_PUBLIC_FIREBASE_PROJECT_ID!,
  storageBucket:     process.env.EXPO_PUBLIC_FIREBASE_STORAGE_BUCKET!,
  messagingSenderId: process.env.EXPO_PUBLIC_FIREBASE_MESSAGING_SENDER_ID!,
  appId:             process.env.EXPO_PUBLIC_FIREBASE_APP_ID!,
};

const app  = getApps().length ? getApps()[0] : initializeApp(firebaseConfig);
export const auth = getAuth(app);

// On React Native, pass a FirebaseRecaptchaVerifierModal as the verifier.
// See: expo-firebase-recaptcha package for the modal component.
export async function sendPhoneOtp(
  phone: string,
  verifier: ApplicationVerifier
): Promise<ConfirmationResult> {
  return signInWithPhoneNumber(auth, phone, verifier);
}

export async function confirmOtp(
  confirmation: ConfirmationResult,
  code: string
): Promise<string> {
  const result  = await confirmation.confirm(code);
  const idToken = await result.user.getIdToken();
  return idToken;
}
