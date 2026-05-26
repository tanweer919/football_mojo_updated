'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { NAV } from '@/lib/nav';

/**
 * Left rail. Highlights the active route by prefix match — `/players/42`
 * still lights up "Players". `usePathname` is the only reason this is a
 * client component; everything else inside is static markup.
 */
export function Sidebar() {
  const pathname = usePathname();
  return (
    <aside className="w-60 shrink-0 border-r border-border bg-bg-deep/80 backdrop-blur sticky top-0 h-screen flex flex-col">
      <Link href="/dashboard" className="flex items-center gap-3 px-5 h-16 border-b border-border hover:bg-surface-1/40 transition-colors">
        <div className="w-7 h-7 rounded-full bg-gradient-to-br from-gold-soft via-gold to-gold-deep shadow-gold-glow" />
        <div className="leading-tight">
          <div className="font-bold tracking-tight">PITCH</div>
          <div className="eyebrow-gold !text-[7.5px]">Admin</div>
        </div>
      </Link>

      <nav className="flex-1 px-3 py-4 space-y-1 overflow-y-auto">
        {NAV.map((item) => {
          const active = pathname === item.href || pathname.startsWith(item.href + '/');
          return (
            <Link
              key={item.href}
              href={item.href}
              className={active ? 'nav-link-active' : 'nav-link'}
            >
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <path d={item.icon} />
              </svg>
              {item.label}
            </Link>
          );
        })}
      </nav>

      <div className="px-5 py-4 border-t border-border text-[10px] text-fg-muted2 font-mono">
        v0.1.0 · build {process.env.NODE_ENV}
      </div>
    </aside>
  );
}
