'use client';

import { useEffect } from 'react';
import { onIdTokenChanged } from 'firebase/auth';
import { firebaseAuth } from '@/lib/firebase-client';

/**
 * Keeps the session cookie in lock-step with Firebase's auto-rotated ID
 * token. Mounted once in the (admin) layout.
 *
 * Firebase JS SDK refreshes the ID token every ~50 minutes; each refresh
 * fires `onIdTokenChanged` with the new token. We POST it back to
 * `/api/session` so the httpOnly cookie always carries a valid token —
 * without this, SSR pages would 401 ~hourly.
 *
 * If `onIdTokenChanged` fires with `null` (sign-out from elsewhere, account
 * disabled, etc.), we DELETE the cookie and bounce to /login.
 */
export function TokenRefresher() {
  useEffect(() => {
    const auth = firebaseAuth();
    const unsub = onIdTokenChanged(auth, async (user) => {
      if (!user) {
        await fetch('/api/session', { method: 'DELETE' });
        if (window.location.pathname !== '/login') {
          window.location.href = '/login';
        }
        return;
      }
      try {
        const idToken = await user.getIdToken();
        await fetch('/api/session', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ idToken }),
        });
      } catch {
        // Network blip — the next change event will retry.
      }
    });
    return () => unsub();
  }, []);

  return null;
}
