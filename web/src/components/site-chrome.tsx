import Image from 'next/image';
import Link from 'next/link';
import { SITE } from '@/lib/site';
import { playUrl } from '@/lib/seo';
import { MobileNav } from '@/components/mobile-nav';

export function SiteHeader() {
  return (
    <header className="sticky top-0 z-50 border-b border-border/60 bg-bg-deep/70 backdrop-blur-xl">
      <div className="container-x flex h-16 items-center justify-between gap-3">
        <Link href="/" className="flex shrink-0 items-center gap-2.5">
          <Image src="/logo.png" alt="FootballMojo logo" width={32} height={32} className="rounded-lg" />
          <span className="text-lg font-extrabold tracking-tight">
            Football<span className="text-gold">Mojo</span>
          </span>
        </Link>
        <nav className="hidden items-center gap-7 text-sm font-medium text-fg-soft sm:flex">
          <Link href="/world-cup-2026" className="transition hover:text-fg">World Cup 2026</Link>
          <Link href="/where-to-watch" className="transition hover:text-fg">Where to Watch</Link>
          <a href="/#features" className="transition hover:text-fg">Features</a>
          <Link href="/privacy" className="transition hover:text-fg">Privacy</Link>
        </nav>
        <div className="flex items-center gap-2">
          <a
            href={playUrl('nav')}
            target="_blank"
            rel="noopener"
            className="btn-gold !px-4 !py-2 text-xs"
          >
            Download
          </a>
          <MobileNav />
        </div>
      </div>
    </header>
  );
}

export function SiteFooter() {
  return (
    <footer className="mt-24 border-t border-border/60">
      <div className="container-x py-12">
        <div className="flex flex-col items-start justify-between gap-8 sm:flex-row">
          <div className="max-w-sm">
            <div className="flex items-center gap-2.5">
              <Image src="/logo.png" alt="FootballMojo logo" width={28} height={28} className="rounded-lg" />
              <span className="text-base font-extrabold tracking-tight">
                Football<span className="text-gold">Mojo</span>
              </span>
            </div>
            <p className="mt-3 text-sm leading-relaxed text-fg-muted">
              The all-in-one football app for the FIFA World Cup 2026 — live scores, brackets,
              fantasy XI, predictions and collectible cards.
            </p>
          </div>
          <div className="grid grid-cols-2 gap-x-10 gap-y-2 text-sm sm:grid-cols-3">
            <div className="flex flex-col gap-2">
              <span className="eyebrow !text-fg-muted2 mb-1">World Cup 2026</span>
              <Link href="/world-cup-2026" className="text-fg-soft transition hover:text-gold">Schedule &amp; scores</Link>
              <Link href="/world-cup-2026/fixtures" className="text-fg-soft transition hover:text-gold">Fixtures</Link>
              <Link href="/world-cup-2026/bracket" className="text-fg-soft transition hover:text-gold">Bracket</Link>
              <Link href="/where-to-watch" className="text-fg-soft transition hover:text-gold">Where to Watch</Link>
            </div>
            <div className="flex flex-col gap-2">
              <span className="eyebrow !text-fg-muted2 mb-1">Football</span>
              <Link href="/leagues/premier-league" className="text-fg-soft transition hover:text-gold">Premier League</Link>
              <Link href="/leagues/champions-league" className="text-fg-soft transition hover:text-gold">Champions League</Link>
              <Link href="/best-football-score-apps" className="text-fg-soft transition hover:text-gold">Best score apps</Link>
              <Link href="/blog" className="text-fg-soft transition hover:text-gold">Blog</Link>
            </div>
            <div className="flex flex-col gap-2">
              <span className="eyebrow !text-fg-muted2 mb-1">Company</span>
              <a href={playUrl('footer')} target="_blank" rel="noopener" className="text-fg-soft transition hover:text-gold">Get the app</a>
              <Link href="/privacy" className="text-fg-soft transition hover:text-gold">Privacy Policy</Link>
              <a href={`mailto:${SITE.contactEmail}`} className="text-fg-soft transition hover:text-gold">Contact</a>
            </div>
          </div>
        </div>
        <div className="hairline my-8" />
        <div className="flex flex-col items-center justify-between gap-3 text-xs text-fg-muted2 sm:flex-row">
          <p>© {new Date().getFullYear()} FootballMojo. All rights reserved.</p>
          <p>Not affiliated with FIFA. “Google Play” is a trademark of Google LLC.</p>
        </div>
      </div>
    </footer>
  );
}
