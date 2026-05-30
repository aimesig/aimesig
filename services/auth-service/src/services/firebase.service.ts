// src/services/firebase.service.ts
import admin from 'firebase-admin';

let firebaseApp: admin.app.App | null = null;

export function initFirebase() {
  if (firebaseApp) return firebaseApp;

  firebaseApp = admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
    }),
  });

  console.log('[Firebase] Admin SDK initialized');
  return firebaseApp;
}

export async function verifyFirebaseToken(token: string) {
  if (!firebaseApp) initFirebase();
  return admin.auth().verifyIdToken(token);
}

/**
 * Create a Firebase user with email + password.
 * Returns the Firebase UID.
 */
export async function createFirebaseEmailUser(
  email: string,
  password: string,
  displayName?: string,
): Promise<string> {
  if (!firebaseApp) initFirebase();
  const record = await admin.auth().createUser({
    email,
    password,
    displayName,
    emailVerified: false,
  });
  return record.uid;
}

/**
 * Update Firebase user properties (e.g. after email-verified in Neon).
 */
export async function updateFirebaseUser(
  uid: string,
  data: Partial<{ emailVerified: boolean; displayName: string; photoURL: string }>,
) {
  if (!firebaseApp) initFirebase();
  return admin.auth().updateUser(uid, data);
}

/**
 * Delete a Firebase user — called when signup is rolled back.
 */
export async function deleteFirebaseUser(uid: string) {
  if (!firebaseApp) initFirebase();
  await admin.auth().deleteUser(uid);
}
