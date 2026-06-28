'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

const TABS = [
  { label: 'Overview', href: '/world-cup-2026', match: (p: string) => p === '/world-cup-2026' },
  { label: 'Fixtures', href: '/world-cup-2026/fixtures', match: (p: string) => p.startsWith('/world-cup-2026/fixtures') },
  { label: 'Groups', href: '/world-cup-2026#standings', match: () => false },
  { label: 'Bracket', href: '/world-cup-2026/bracket', match: (p: string) => p.startsWith('/world-cup-2026/bracket') },
];

/** Section tabs for the World Cup pages — a lightweight in-page strip, not a
 *  second sticky nav bar (the global header is the only sticky nav). */
export function WcSubnav() {
  const pathname = usePathname() ?? '';
  return (
    <nav aria-label="World Cup 2026 sections" className="border-b border-border/50">
      <div className="container-x -mb-px flex gap-1 overflow-x-auto pt-4">
        {TABS.map((t) => {
          const active = t.match(pathname);
          return (
            <Link
              key={t.href}
              href={t.href}
              className={
                'shrink-0 whitespace-nowrap border-b-2 px-3 pb-2.5 text-sm font-semibold transition ' +
                (active
                  ? 'border-gold text-gold'
                  : 'border-transparent text-fg-muted hover:text-fg')
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
