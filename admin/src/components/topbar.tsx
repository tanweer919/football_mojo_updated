'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { firebaseAuth } from '@/lib/firebase-client';
import { Button } from './ui';

/**
 * Topbar — page title slot on the left, user identity + sign-out on the
 * right. Client component because we read the live Firebase user (which
 * gives us name + email + photoUrl without a backend round-trip).
 *
 * The user's role is shipped in by the server-rendered (admin) layout so
 * we don't have to re-fetch it here just to display a badge.
 */
export function Topbar({ title, role }: { title: string; role: string }) {
  const router = useRouter();
  const [user, setUser] = useState<{ name: string; email: string; photoUrl: string | null } | null>(null);
  const [signingOut, setSigningOut] = useState(false);

  useEffect(() => {
    return firebaseAuth().onAuthStateChanged((u) => {
      if (!u) { setUser(null); return; }
      setUser({
        name: u.displayName ?? u.email ?? 'Admin',
        email: u.email ?? '',
        photoUrl: u.photoURL ?? null,
      });
    });
  }, []);

  async function onSignOut() {
    setSigningOut(true);
    try {
      // Order matters: kill the cookie first, then the client session.
      // If we did it the other way the TokenRefresher would race the
      // sign-out and POST a new cookie right after we deleted it.
      await fetch('/api/session', { method: 'DELETE' });
      await firebaseAuth().signOut();
      router.replace('/login');
      router.refresh();
    } finally {
      setSigningOut(false);
    }
  }

  return (
    <div className="h-16 px-6 border-b border-border flex items-center justify-between bg-bg-deep/80 backdrop-blur sticky top-0 z-10">
      <h1 className="text-base font-bold tracking-tight">{title}</h1>

      <div className="flex items-center gap-4">
        <div className="text-right leading-tight hidden sm:block">
          <div className="text-sm font-medium">{user?.name ?? '…'}</div>
          <div className="text-[10px] font-mono tracking-wider uppercase text-gold">{role}</div>
        </div>
        {user?.photoUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={user.photoUrl}
            alt=""
            className="w-9 h-9 rounded-full border border-gold/40 shadow-gold-glow"
            referrerPolicy="no-referrer"
          />
        ) : (
          <div className="w-9 h-9 rounded-full bg-gradient-to-br from-gold-soft to-gold-deep flex items-center justify-center text-[#1E1810] font-bold text-sm shadow-gold-glow">
            {initials(user?.name ?? 'A')}
          </div>
        )}
        <Button variant="ghost" size="sm" onClick={onSignOut} disabled={signingOut} title="Sign out">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9" />
          </svg>
        </Button>
      </div>
    </div>
  );
}

function initials(name: string): string {
  const parts = name.trim().split(/\s+/);
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
  return name.slice(0, 2).toUpperCase();
}
