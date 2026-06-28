'use client';

import { useState } from 'react';
import Link from 'next/link';
import { playUrl } from '@/lib/seo';

const LINKS = [
  { href: '/world-cup-2026', label: 'World Cup 2026' },
  { href: '/world-cup-2026/fixtures', label: 'Fixtures' },
  { href: '/world-cup-2026/bracket', label: 'Bracket' },
  { href: '/where-to-watch', label: 'Where to Watch' },
  { href: '/best-football-score-apps', label: 'Best score apps' },
  { href: '/blog', label: 'Blog' },
  { href: '/privacy', label: 'Privacy' },
];

/** Hamburger + slide-down menu for small screens. */
export function MobileNav() {
  const [open, setOpen] = useState(false);
  return (
    <div className="sm:hidden">
      <button
        type="button"
        aria-label={open ? 'Close menu' : 'Open menu'}
        aria-expanded={open}
        onClick={() => setOpen((v) => !v)}
        className="grid h-10 w-10 place-items-center rounded-lg border border-border/70 text-fg-soft transition hover:text-fg"
      >
        <span className="relative block h-4 w-5">
          <span className={`absolute left-0 block h-0.5 w-5 rounded bg-current transition-all ${open ? 'top-1.5 rotate-45' : 'top-0'}`} />
          <span className={`absolute left-0 top-1.5 block h-0.5 w-5 rounded bg-current transition-all ${open ? 'opacity-0' : 'opacity-100'}`} />
          <span className={`absolute left-0 block h-0.5 w-5 rounded bg-current transition-all ${open ? 'top-1.5 -rotate-45' : 'top-3'}`} />
        </span>
      </button>

      {open && (
        <>
          <button
            type="button"
            aria-hidden
            tabIndex={-1}
            onClick={() => setOpen(false)}
            className="fixed inset-x-0 bottom-0 top-16 z-40 cursor-default bg-black/50"
          />
          <div className="absolute inset-x-0 top-16 z-50 border-b border-border bg-bg-deep px-3 pb-4 pt-2 shadow-2xl">
            <nav className="flex flex-col">
              {LINKS.map((l) => (
                <Link
                  key={l.href}
                  href={l.href}
                  onClick={() => setOpen(false)}
                  className="rounded-lg px-3 py-3 text-base font-semibold text-fg-soft transition hover:bg-surface-1 hover:text-fg"
                >
                  {l.label}
                </Link>
              ))}
              <a
                href={playUrl('mobile-nav')}
                target="_blank"
                rel="noopener"
                onClick={() => setOpen(false)}
                className="btn-gold mt-3 justify-center !py-3 text-sm"
              >
                Get it on Google Play
              </a>
            </nav>
          </div>
        </>
      )}
    </div>
  );
}
