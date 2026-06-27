'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

const TABS = [
  { label: 'Overview', href: '/world-cup-2026', match: (p: string) => p === '/world-cup-2026' },
  { label: 'Fixtures', href: '/world-cup-2026/fixtures', match: (p: string) => p.startsWith('/world-cup-2026/fixtures') },
  { label: 'Groups', href: '/world-cup-2026#standings', match: () => false },
  { label: 'Bracket', href: '/world-cup-2026/bracket', match: (p: string) => p.startsWith('/world-cup-2026/bracket') },
];

/** Sticky sub-navigation for the World Cup section so the pages interlink. */
export function WcSubnav() {
  const pathname = usePathname() ?? '';
  return (
    <nav aria-label="World Cup 2026 sections" className="sticky top-16 z-40 border-b border-border/60 bg-bg-deep/80 backdrop-blur">
      <div className="container-x flex gap-1 overflow-x-auto py-2">
        {TABS.map((t) => {
          const active = t.match(pathname);
          return (
            <Link
              key={t.href}
              href={t.href}
              className={
                'shrink-0 rounded-full px-4 py-1.5 text-sm font-semibold transition ' +
                (active ? 'bg-gold/15 text-gold' : 'text-fg-soft hover:bg-surface-1 hover:text-fg')
              }
            >
              {t.label}
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
