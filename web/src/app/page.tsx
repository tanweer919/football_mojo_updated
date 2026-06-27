import type { Metadata } from 'next';
import Link from 'next/link';
import { PlayButton } from '@/components/play-button';
import { PhoneFrame } from '@/components/phone';
import { SITE } from '@/lib/site';

// Homepage metadata — tight, keyword-front-loaded title (≤60) + description
// (≤155), overriding the longer layout defaults. `absolute` bypasses the
// "%s · FootballMojo" template so the title isn't double-branded.
export const metadata: Metadata = {
  title: { absolute: 'FootballMojo: Live Scores, World Cup 2026 & Fantasy' },
  description:
    'Free football app: live scores, FIFA World Cup 2026 schedule, fixtures & bracket, fantasy and AI match previews & recaps — no betting, no gambling.',
  alternates: { canonical: '/', languages: { 'x-default': '/', en: '/' } },
  openGraph: {
    title: 'FootballMojo — Live Football Scores, World Cup 2026 & Fantasy',
    description:
      'Live scores, World Cup 2026 fixtures, bracket, fantasy and AI previews. Free, family-safe, no betting.',
  },
};

// ─── Data ───────────────────────────────────────────────────────────────────

const STATS = [
  { value: '48', label: 'Teams' },
  { value: '104', label: 'Matches' },
  { value: 'Live', label: 'Scores' },
  { value: 'Free', label: 'To play' },
];

const FEATURES = [
  {
    icon: '⚽',
    title: 'Live scores & match centre',
    body: 'Real-time scores, lineups, events and stats for every World Cup 2026 fixture — never miss a goal.',
  },
  {
    icon: '🏆',
    title: 'Full tournament bracket',
    body: 'Predict the entire knockout tree from the group stage to the final and watch your bracket score live.',
  },
  {
    icon: '🎯',
    title: 'Score predictions',
    body: 'Call the scoreline for every match, earn points for accuracy and climb the global leaderboard.',
  },
  {
    icon: '🧤',
    title: 'Fantasy XI',
    body: 'Build your dream XI within budget, pick a captain and rack up points from real-world performances.',
  },
  {
    icon: '🃏',
    title: 'Collectible player cards',
    body: 'Earn and collect rare player cards — and the ones you own boost that player in your fantasy XI.',
  },
  {
    icon: '👥',
    title: 'Head-to-head leagues',
    body: 'Create private leagues, invite friends and settle who really knows their football.',
  },
];

const GALLERY = [
  { src: '/screenshots/home.png', alt: 'FootballMojo home screen with live World Cup scores' },
  { src: '/screenshots/bracket.png', alt: 'World Cup 2026 prediction bracket in FootballMojo' },
  { src: '/screenshots/fantasy.png', alt: 'Fantasy XI builder in FootballMojo' },
  { src: '/screenshots/cards.png', alt: 'Collectible player card collection in FootballMojo' },
  { src: '/screenshots/news.png', alt: 'Football news feed in FootballMojo' },
];

const FAQ = [
  {
    q: 'Is FootballMojo free?',
    a: 'Yes. FootballMojo is free to download and play — live scores, brackets, predictions, fantasy XI and card collecting are all included. It is supported by ads.',
  },
  {
    q: 'Which tournament does it cover?',
    a: 'FootballMojo is built for the FIFA World Cup 2026 — all 48 teams and 104 matches — with live scores, a full prediction bracket, fantasy and more.',
  },
  {
    q: 'Is there any gambling or betting?',
    a: 'No. FootballMojo has no gambling, betting or wagering of any kind. Predictions and cards are for fun and bragging rights only — cards are collectibles, never bought with money for a chance at a random reward.',
  },
  {
    q: 'What platforms is it on?',
    a: 'FootballMojo is available on Android via the Google Play Store. Tap “Get it on Google Play” to install.',
  },
  {
    q: 'How do collectible cards work in fantasy?',
    a: 'You earn player cards by playing. If you own a card of a player in your fantasy XI, that player gets a points boost — rarer cards give a bigger boost.',
  },
];

// ─── Page ────────────────────────────────────────────────────────────────────

export default function HomePage() {
  const faqLd = {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: FAQ.map((f) => ({
      '@type': 'Question',
      name: f.q,
      acceptedAnswer: { '@type': 'Answer', text: f.a },
    })),
  };

  return (
    <>
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(faqLd) }} />

      {/* ─── Hero ─────────────────────────────────────────────────────── */}
      <section className="relative overflow-hidden">
        <div className="container-x grid items-center gap-12 py-16 sm:py-24 lg:grid-cols-2">
          <div className="animate-fadeup">
            <span className="eyebrow">
              <span className="inline-block h-1.5 w-1.5 rounded-full bg-gold" />
              FIFA World Cup 2026
            </span>
            <h1 className="mt-5 font-display text-4xl font-extrabold leading-[1.05] tracking-tight sm:text-5xl lg:text-6xl">
              Your World Cup,
              <br />
              <span className="text-gold-grad">all in one app.</span>
            </h1>
            <p className="mt-6 max-w-xl text-lg leading-relaxed text-fg-soft">
              Live scores, the full prediction bracket, fantasy XI, score predictions and
              collectible player cards — everything for the FIFA World Cup 2026, in your pocket.
            </p>
            <div className="mt-8 flex flex-wrap items-center gap-4">
              <PlayButton />
              <a href="#features" className="btn-ghost">See what’s inside</a>
            </div>
            <p className="mt-5 text-sm text-fg-muted">Free · No gambling · Built for the 2026 World Cup</p>
          </div>

          <div className="relative flex justify-center">
            {/* glow */}
            <div className="absolute inset-0 -z-10 mx-auto h-[420px] w-[420px] rounded-full bg-gold/10 blur-3xl" />
            <PhoneFrame
              src={GALLERY[0].src}
              alt={GALLERY[0].alt}
              priority
              className="animate-floaty"
            />
          </div>
        </div>

        {/* Stat bar */}
        <div className="container-x">
          <div className="panel grid grid-cols-2 divide-x divide-border/60 sm:grid-cols-4">
            {STATS.map((s) => (
              <div key={s.label} className="px-4 py-6 text-center">
                <div className="font-display text-3xl font-extrabold text-gold">{s.value}</div>
                <div className="mt-1 text-xs font-medium uppercase tracking-wider text-fg-muted">{s.label}</div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ─── Features ─────────────────────────────────────────────────── */}
      <section id="features" className="container-x py-20 sm:py-28">
        <div className="mx-auto max-w-2xl text-center">
          <span className="eyebrow">Everything for matchday</span>
          <h2 className="mt-4 font-display text-3xl font-extrabold tracking-tight sm:text-4xl">
            One app. The whole tournament.
          </h2>
          <p className="mt-4 text-fg-soft">
            From the opening whistle to the final, FootballMojo keeps you in the game.
          </p>
        </div>

        <div className="mt-14 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {FEATURES.map((f) => (
            <div
              key={f.title}
              className="panel group p-6 transition hover:-translate-y-1 hover:border-gold/30 hover:shadow-gold-glow"
            >
              <div className="flex h-11 w-11 items-center justify-center rounded-xl border border-gold/25 bg-gold/10 text-xl">
                {f.icon}
              </div>
              <h3 className="mt-4 text-lg font-bold">{f.title}</h3>
              <p className="mt-2 text-sm leading-relaxed text-fg-muted">{f.body}</p>
            </div>
          ))}
        </div>
      </section>

      {/* ─── Screenshot gallery ──────────────────────────────────────── */}
      <section className="relative overflow-hidden py-10">
        <div className="container-x">
          <div className="mx-auto mb-12 max-w-2xl text-center">
            <span className="eyebrow">Take a look</span>
            <h2 className="mt-4 font-display text-3xl font-extrabold tracking-tight sm:text-4xl">
              Beautiful on every screen
            </h2>
          </div>
          <div className="flex snap-x gap-6 overflow-x-auto pb-6 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden sm:justify-center sm:flex-wrap sm:overflow-visible">
            {GALLERY.map((g, i) => (
              <PhoneFrame
                key={g.src}
                src={g.src}
                alt={g.alt}
                className={`shrink-0 snap-center !max-w-[220px] ${i % 2 ? 'sm:translate-y-6' : ''}`}
              />
            ))}
          </div>
        </div>
      </section>

      {/* ─── World Cup 2026 band ─────────────────────────────────────── */}
      <section id="worldcup" className="container-x py-20 sm:py-28">
        <div className="panel grid items-center gap-12 overflow-hidden p-8 sm:p-12 lg:grid-cols-2">
          <div>
            <span className="eyebrow">World Cup 2026</span>
            <h2 className="mt-4 font-display text-3xl font-extrabold tracking-tight sm:text-4xl">
              Predict the bracket. Own the bragging rights.
            </h2>
            <p className="mt-5 leading-relaxed text-fg-soft">
              Fill in your full FIFA World Cup 2026 bracket — from the 48-team group stage through
              every knockout round to the final in New York. As real results come in, your bracket
              scores automatically and you climb the global leaderboard against fans worldwide.
            </p>
            <ul className="mt-6 space-y-3 text-sm text-fg-soft">
              {[
                'All 48 teams, all 104 matches',
                'Live, automatic bracket scoring',
                'Global & private friend leaderboards',
              ].map((t) => (
                <li key={t} className="flex items-center gap-3">
                  <span className="flex h-5 w-5 items-center justify-center rounded-full bg-pitch/20 text-pitch">✓</span>
                  {t}
                </li>
              ))}
            </ul>
            <div className="mt-8 flex flex-wrap items-center gap-x-6 gap-y-3">
              <PlayButton />
              <Link
                href="/world-cup-2026"
                className="text-sm font-semibold text-gold transition hover:text-gold-soft"
              >
                World Cup 2026 schedule, fixtures &amp; bracket →
              </Link>
            </div>
          </div>
          <div className="relative flex justify-center">
            <div className="absolute inset-0 -z-10 mx-auto h-72 w-72 rounded-full bg-pitch/10 blur-3xl" />
            <PhoneFrame src={GALLERY[1].src} alt={GALLERY[1].alt} className="animate-floaty" />
          </div>
        </div>
      </section>

      {/* ─── Collect & compete band ──────────────────────────────────── */}
      <section className="container-x py-10 sm:py-16">
        <div className="grid items-center gap-12 lg:grid-cols-2">
          <div className="order-2 flex justify-center gap-5 lg:order-1">
            <PhoneFrame src={GALLERY[3].src} alt={GALLERY[3].alt} className="!max-w-[210px] sm:translate-y-6" />
            <PhoneFrame src={GALLERY[2].src} alt={GALLERY[2].alt} className="!max-w-[210px]" />
          </div>
          <div className="order-1 lg:order-2">
            <span className="eyebrow">Collect &amp; compete</span>
            <h2 className="mt-4 font-display text-3xl font-extrabold tracking-tight sm:text-4xl">
              Cards that actually mean something
            </h2>
            <p className="mt-5 leading-relaxed text-fg-soft">
              Earn collectible player cards as you play, then put them to work: any player whose card
              you own gets a points boost in your fantasy XI — the rarer the card, the bigger the
              edge. Build the squad, captain your star, and watch the points roll in.
            </p>
            <p className="mt-4 text-sm text-fg-muted">
              Cards are collectibles only — no gambling, no random paid packs. What you see is what you get.
            </p>
          </div>
        </div>
      </section>

      {/* ─── FAQ ──────────────────────────────────────────────────────── */}
      <section id="faq" className="container-x py-20 sm:py-28">
        <div className="mx-auto max-w-3xl">
          <div className="mb-12 text-center">
            <span className="eyebrow">Good to know</span>
            <h2 className="mt-4 font-display text-3xl font-extrabold tracking-tight sm:text-4xl">
              Frequently asked questions
            </h2>
          </div>
          <div className="space-y-3">
            {FAQ.map((f) => (
              <details key={f.q} className="panel group p-5 [&_summary::-webkit-details-marker]:hidden">
                <summary className="flex cursor-pointer list-none items-center justify-between gap-4 font-semibold text-fg">
                  {f.q}
                  <span className="text-gold transition group-open:rotate-45">+</span>
                </summary>
                <p className="mt-3 text-sm leading-relaxed text-fg-muted">{f.a}</p>
              </details>
            ))}
          </div>
        </div>
      </section>

      {/* ─── Final CTA ────────────────────────────────────────────────── */}
      <section className="container-x pb-8">
        <div className="panel relative overflow-hidden px-6 py-14 text-center sm:px-12">
          <div className="absolute inset-0 -z-10 bg-gradient-to-br from-gold/10 via-transparent to-pitch/10" />
          <h2 className="mx-auto max-w-2xl font-display text-3xl font-extrabold tracking-tight sm:text-4xl">
            Kick off your World Cup 2026 with <span className="text-gold-grad">{SITE.name}</span>
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-fg-soft">
            Free to download. No gambling. Just the beautiful game, all in one place.
          </p>
          <div className="mt-8 flex justify-center">
            <PlayButton />
          </div>
        </div>
      </section>
    </>
  );
}
