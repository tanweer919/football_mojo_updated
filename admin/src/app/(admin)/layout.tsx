import type { ReactNode } from 'react';
import { Sidebar } from '@/components/sidebar';
import { TokenRefresher } from '@/components/token-refresher';

/**
 * Authenticated shell. Middleware has already guaranteed a session cookie
 * exists by the time anything under this route group renders. The
 * `TokenRefresher` keeps that cookie current as Firebase rotates its ID
 * token under us.
 *
 * Topbar is rendered *inside* each page rather than here, so pages pass
 * their own dynamic title (e.g. a player's name on the edit screen)
 * without prop-drilling through this layout.
 */
export default function AdminLayout({ children }: { children: ReactNode }) {
  return (
    <div className="flex min-h-screen">
      <Sidebar />
      <main className="flex-1 min-w-0">{children}</main>
      <TokenRefresher />
    </div>
  );
}
