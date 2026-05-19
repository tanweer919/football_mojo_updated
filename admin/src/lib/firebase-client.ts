'use client';

import { initializeApp, getApps, type FirebaseApp } from 'firebase/app';
import { getAuth, GoogleAuthProvider, type Auth } from 'firebase/auth';

/**
 * Browser-side Firebase singleton. Same project as the Flutter app — we
 * deliberately share the Firebase project so a user signing into both
 * surfaces has the same Firebase UID, which is also their Postgres
 * `User.id`.
 *
 * Only reads `NEXT_PUBLIC_FIREBASE_*` env vars, all of which are public by
 * design (Firebase web config is shipped to the browser anyway).
 */

const config = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN,
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
};

let _app: FirebaseApp | null = null;
let _auth: Auth | null = null;

export function firebaseApp(): FirebaseApp {
  if (_app) return _app;
  _app = getApps()[0] ?? initializeApp(config);
  return _app;
}

export function firebaseAuth(): Auth {
  if (_auth) return _auth;
  _auth = getAuth(firebaseApp());
  return _auth;
}

export const googleProvider = new GoogleAuthProvider();
