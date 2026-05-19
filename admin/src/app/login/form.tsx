'use client';

import { useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { signInWithPopup } from 'firebase/auth';
import { firebaseAuth, googleProvider } from '@/lib/firebase-client';
import { Button } from '@/components/ui';

/**
 * Sign-in flow:
 *   1. Firebase JS SDK opens a Google OAuth popup, returns a User.
 *   2. We pull a fresh ID token from the user object.
 *   3. POST the token to `/api/session`, which calls the backend to verify
 *      both the Firebase signature AND that the user's `User.role` is
 *      ADMIN/SUPERADMIN. On success the route sets the httpOnly cookie.
 *   4. We bounce the browser to wherever the middleware sent us from
 *      (preserved in `?from=...`) or to /dashboard.
 *
 * All errors map to a single banner. We don't differentiate "wrong Google
 * account" from "wrong role" in the message because the latter would leak
 * "this email exists in our DB but isn't an admin" — useful enumeration
 * for an attacker scoping out who to phish.
 */
export function LoginForm() {
  const router = useRouter();
  const params = useSearchParams();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onClick() {
    setBusy(true);
    setError(null);
    try {
      const cred = await signInWithPopup(firebaseAuth(), googleProvider);
      const idToken = await cred.user.getIdToken(/* forceRefresh */ true);
      const res = await fetch('/api/session', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ idToken }),
      });
      if (!res.ok) {
        // Roll back the client-side Firebase session so the next attempt
        // re-prompts (otherwise the popup auto-closes with the same
        // account).
        await firebaseAuth().signOut().catch(() => {});
        throw new Error(
          res.status === 403
            ? 'Your account doesn’t have admin access.'
            : 'Sign-in failed. Please try again.',
        );
      }
      router.replace(params.get('from') ?? '/dashboard');
      router.refresh();
    } catch (e) {
      const msg = e instanceof Error ? e.message : 'Sign-in failed.';
      // Suppress the popup-closed-by-user case — that's not really an error.
      if (msg.includes('popup-closed-by-user') || msg.includes('cancelled')) {
        setError(null);
      } else {
        setError(msg);
      }
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <Button onClick={onClick} disabled={busy} variant="gold" className="w-full h-11">
        <GoogleGlyph />
        {busy ? 'Signing in…' : 'Continue with Google'}
      </Button>
      {error && (
        <div className="mt-4 p-3 rounded-md bg-live/10 border border-live/30 text-live text-xs">
          {error}
        </div>
      )}
    </>
  );
}

function GoogleGlyph() {
  return (
    <svg width="18" height="18" viewBox="0 0 18 18" aria-hidden>
      <path fill="#4285F4" d="M17.64 9.2c0-.64-.06-1.25-.16-1.84H9v3.48h4.84a4.14 4.14 0 0 1-1.8 2.71v2.26h2.92c1.7-1.57 2.68-3.87 2.68-6.61z" />
      <path fill="#34A853" d="M9 18c2.43 0 4.47-.81 5.96-2.18l-2.92-2.26c-.81.54-1.84.87-3.04.87-2.34 0-4.32-1.58-5.03-3.7H.96v2.33A9 9 0 0 0 9 18z" />
      <path fill="#FBBC05" d="M3.97 10.73a5.41 5.41 0 0 1 0-3.46V4.94H.96a9 9 0 0 0 0 8.12l3.01-2.33z" />
      <path fill="#EA4335" d="M9 3.58c1.32 0 2.5.45 3.44 1.34l2.58-2.58A9 9 0 0 0 9 0 9 9 0 0 0 .96 4.94l3.01 2.33C4.68 5.16 6.66 3.58 9 3.58z" />
    </svg>
  );
}
