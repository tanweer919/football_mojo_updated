import { cookies } from 'next/headers';

/**
 * Session is a thin wrapper over a single httpOnly cookie holding the
 * Firebase ID token (the same token the mobile app sends as a bearer).
 *
 * Why ID token + cookie instead of NextAuth or Firebase session cookies:
 *   - The backend already verifies ID tokens via `FirebaseAuthGuard`. Using
 *     the same token here means one verification path, server-side.
 *   - The client (Firebase JS SDK) auto-refreshes the ID token every ~50
 *     minutes. The `<TokenRefresher>` component re-POSTs to /api/session
 *     so the cookie tracks the latest.
 *   - httpOnly + secure + samesite=lax keeps the token out of XSS reach
 *     and survives full-page reloads.
 */

export const SESSION_COOKIE = 'pitch_admin_id_token';
// Firebase ID tokens expire after 60 minutes. We set the cookie a touch
// longer (75 min) so a request that catches an "about to expire" token
// still completes — the client refresher tops it back up before then.
export const SESSION_MAX_AGE_S = 60 * 75;

export function readSessionToken(): string | null {
  const c = cookies().get(SESSION_COOKIE);
  return c?.value ?? null;
}
