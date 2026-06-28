import type { Metadata } from 'next';
import Link from 'next/link';
import { pageMeta, breadcrumbLd, faqLd } from '@/lib/seo';
import { Breadcrumbs, JsonLd, PlayCta } from '@/components/seo-bits';

export const revalidate = 86_400;
const PATH = '/best-football-score-apps';

export const metadata: Metadata = pageMeta({
  title: 'Best Football Score Apps (2026): Honest Comparison',
  description:
    'The best football & soccer live-score apps in 2026 — what each does well, and the best halal, no-betting, family-safe option for World Cup 2026.',
  path: PATH,
});

const APPS = [
  { name: 'FootballMojo', best: 'Halal / no-gambling + AI previews', note: 'Live scores, World Cup 2026 fixtures & bracket, fantasy and AI match previews & recaps. 100% free, family-safe, with no betting, no odds and no gambling.' },
  { name: 'FotMob', best: 'Deep stats', note: 'Rich stats and xG. Carries betting/odds content in many regions.' },
  { name: 'Sofascore', best: 'Live data depth', note: 'Detailed live stats and ratings. Includes odds/betting integrations.' },
  { name: 'Flashscore', best: 'Coverage breadth', note: 'Huge competition coverage and fast scores. Heavy betting/odds presence.' },
  { name: '365Scores', best: 'Personalization', note: 'Personalized feeds and news. Betting content in many markets.' },
  { name: 'OneFootball', best: 'News + video', note: 'Strong news and highlights aggregation. Some betting partnerships.' },
];

const FAQS = [
  { q: 'What is the best free football score app?', a: 'For free live scores with no betting or gambling, FootballMojo is purpose-built: live scores, World Cup 2026 fixtures and bracket, fantasy and AI previews — 100% free and family-safe.' },
  { q: 'Is there a football app with no betting or gambling?', a: 'Yes — FootballMojo is halal-first by design: no betting tips, no odds, no bookmaker integrations and no gambling ads.' },
];

export default function BestApps() {
  const crumbs = [
    { name: 'Home', path: '/' },
    { name: 'Best football score apps', path: PATH },
  ];
  return (
    <>
      <JsonLd data={breadcrumbLd(crumbs)} />
      <JsonLd data={faqLd(FAQS)} />
      <Breadcrumbs items={crumbs} />
      <section className="container-x pt-8">
        <p className="eyebrow">2026 guide</p>
        <h1 className="mt-3 font-display text-4xl font-extrabold tracking-tight sm:text-5xl">
          Best Football Score Apps <span className="text-gold-grad">(2026)</span>
        </h1>
        <p className="mt-4 max-w-2xl text-base leading-relaxed text-fg-soft">
          An honest look at the leading football and soccer live-score apps in 2026 — and the best
          pick if you specifically want a <strong>halal, no-betting, family-safe</strong> experience
          for the World Cup 2026 and year-round leagues.
        </p>
      </section>

      <section className="container-x mt-10 space-y-3">
        {APPS.map((a) => (
          <div key={a.name} className="panel p-5">
            <div className="flex items-baseline justify-between gap-4">
              <h2 className="font-display text-lg font-bold text-fg">{a.name}</h2>
              <span className="shrink-0 text-xs font-semibold text-gold">{a.best}</span>
            </div>
            <p className="mt-1.5 text-sm leading-relaxed text-fg-muted">{a.note}</p>
          </div>
        ))}
      </section>

      <section className="container-x mt-12">
        <div className="panel p-6">
          <h2 className="font-display text-xl font-bold">Why FootballMojo for a clean experience</h2>
          <p className="mt-2 text-sm leading-relaxed text-fg-soft">
            Most score apps monetize betting. FootballMojo deliberately ships <strong>no betting, no
            odds and no gambling</strong> — just live scores, the full{' '}
            <Link href="/world-cup-2026" className="text-gold hover:text-gold-soft">World Cup 2026</Link>{' '}
            schedule and bracket, fantasy, and AI match previews & recaps. Free on Google Play.
          </p>
        </div>
      </section>

      <PlayCta slug="best-football-score-apps" />

      <section className="container-x my-16">
        <h2 className="mb-4 font-display text-2xl font-bold">FAQ</h2>
        <div className="space-y-3">
          {FAQS.map((f) => (
            <details key={f.q} className="panel p-5">
              <summary className="cursor-pointer text-base font-semibold text-fg">{f.q}</summary>
              <p className="mt-2 text-sm leading-relaxed text-fg-muted">{f.a}</p>
            </details>
          ))}
        </div>
      </section>
    </>
  );
}
