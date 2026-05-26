import admin from 'firebase-admin';

let firebaseApp: admin.app.App | null = null;

export function initFirebase() {
  if (firebaseApp) {
    return firebaseApp;
  }

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
  if (!firebaseApp) {
    initFirebase();
  }

  return await admin.auth().verifyIdToken(token);
}