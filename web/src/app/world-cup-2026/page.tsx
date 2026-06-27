import type { Metadata } from 'next';
import Link from 'next/link';
import { pageMeta, breadcrumbLd, faqLd, appLd } from '@/lib/seo';
import { getGroups, getCompetitionFixtures } from '@/lib/api';
import { WC, WC_PHASES, HOST_CITIES } from '@/lib/wc';
import { Breadcrumbs, JsonLd, PlayCta } from '@/components/seo-bits';
import { FixtureList, GroupTable, ComingSoon } from '@/components/match-bits';

export const revalidate = 600; // 10 min ISR

const SLUG = 'world-cup-2026';
const PATH = '/world-cup-2026';

export const metadata: Metadata = pageMeta({
  title: 'World Cup 2026 Schedule, Fixtures & Live Scores',
  description:
    'Full FIFA World Cup 2026 schedule, fixtures, live scores, group standings, knockout bracket and host cities — free, with no betting or ads. Get live goal alerts.',
  path: PATH,
  ogTitle: 'FIFA World Cup 2026 — Schedule, Fixtures, Live Scores & Bracket',
});

const FAQS = [
  { q: 'When is the FIFA World Cup 2026?', a: `The 2026 World Cup runs from ${WC.startDate} to ${WC.endDate}, hosted across the United States, Canada and Mexico — the first 48-team, 104-match edition.` },
  { q: 'What is the World Cup 2026 format?', a: 'Forty-eight teams in twelve groups of four. The top two from each group plus the eight best third-placed teams advance to a Round of 32, then Round of 16, quarter-finals, semi-finals and the final.' },
  { q: 'Where can I watch World Cup 2026 live scores?', a: 'FootballMojo gives free live scores, fixtures, group tables and the full bracket, plus instant goal and full-time alerts and AI match previews and recaps — with no betting, no odds and no gambling.' },
  { q: 'Is FootballMojo free?', a: 'Yes. FootballMojo is 100% free on Google Play, family-safe, and contains no betting or gambling features.' },
];

export default async function WorldCup2026Hub() {
  const today = new Date();
  const from = new Date(today.getTime() - 3 * 86_400_000).toISOString().slice(0, 10);
  const to = new Date(today.getTime() + 12 * 86_400_000).toISOString().slice(0, 10);

  const [groups, fixtures] = await Promise.all([
    getGroups(WC.competitionId),
    getCompetitionFixtures(WC.competitionNameMatch, from, to),
  ]);

  const isKnockout = (s?: string | null) => !!s && !/^GROUP/i.test(s);
  const upcoming = fixtures.filter((f) => f.status === 'SCHEDULED').slice(0, 8);
  const recent = fixtures.filter((f) => ['FINISHED', 'FT', 'AET', 'PEN'].includes(f.status)).slice(-6).reverse();
  const knockout = fixtures.filter((f) => isKnockout(f.stage)).slice(0, 16);

  const crumbs = [
    { name: 'Home', path: '/' },
    { name: 'World Cup 2026', path: PATH },
  ];

  return (
    <>
      <JsonLd data={breadcrumbLd(crumbs)} />
      <JsonLd data={faqLd(FAQS)} />
      <JsonLd data={appLd()} />
      <Breadcrumbs items={crumbs} />

      {/* Hero */}
      <section className="container-x pt-8">
        <p className="eyebrow">FIFA World Cup 2026 · USA · Canada · Mexico</p>
        <h1 className="mt-3 font-display text-4xl font-extrabold leading-tight tracking-tight sm:text-5xl">
          World Cup 2026 <span className="text-gold-grad">Schedule, Fixtures &amp; Live Scores</span>
        </h1>
        <p className="mt-4 max-w-2xl text-base leading-relaxed text-fg-soft">
          The complete FIFA World Cup 2026 hub — full match schedule, live scores, group standings,
          the knockout bracket and all 16 host cities. {WC.teamCount} teams, {WC.matchCount} matches,
          across three nations. Follow every fixture and get instant goal alerts in the free
          FootballMojo app — no betting, no gambling, family-safe.
        </p>
      </section>

      {/* Live / upcoming */}
      <section className="container-x mt-12">
        <div className="mb-4 flex items-end justify-between">
          <h2 className="font-display text-2xl font-bold">Fixtures &amp; results</h2>
          <Link href={`${PATH}/fixtures`} className="text-sm font-medium text-gold transition hover:text-gold-soft">
            All fixtures →
          </Link>
        </div>
        {recent.length > 0 && (
          <>
            <h3 className="eyebrow mb-3 !text-fg-muted">Latest results</h3>
            <FixtureList fixtures={recent} />
          </>
        )}
        {upcoming.length > 0 && (
          <>
            <h3 className="eyebrow mb-3 mt-8 !text-fg-muted">Upcoming</h3>
            <FixtureList fixtures={upcoming} />
          </>
        )}
        {recent.length === 0 && upcoming.length === 0 && (
          <ComingSoon title="Fixtures load as they're scheduled" note="Match data appears here automatically as the tournament progresses. Check back soon." />
        )}
      </section>

      {/* Group standings */}
      <section className="container-x mt-16">
        <div className="mb-4 flex items-end justify-between">
          <h2 className="font-display text-2xl font-bold">Group standings</h2>
        </div>
        {groups.length > 0 ? (
          <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
            {groups.map((g) => <GroupTable key={g.id} group={g} />)}
          </div>
        ) : (
          <ComingSoon title="Group tables update live as matches are played" note="The twelve group tables appear here the moment the group stage kicks off." />
        )}
      </section>

      {/* Knockout bracket */}
      <section className="container-x mt-16">
        <h2 className="mb-4 font-display text-2xl font-bold">Knockout bracket</h2>
        {knockout.length > 0 ? (
          <FixtureList fixtures={knockout} />
        ) : (
          <ComingSoon
            title="Round of 32 begins 28 June 2026"
            note="The knockout bracket fills in once the group stage finishes and the Round of 32 ties are set. Follow it live — and predict the whole bracket — in the app."
          />
        )}
      </section>

      {/* Format */}
      <section className="container-x mt-16">
        <h2 className="mb-4 font-display text-2xl font-bold">Tournament format &amp; key dates</h2>
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {WC_PHASES.map((p) => (
            <div key={p.key} className="panel p-5">
              <h3 className="font-display text-base font-bold text-fg">{p.label}</h3>
              <p className="mt-1 text-sm text-fg-muted">{fmtRange(p.from, p.to)}</p>
              <p className="mt-2 text-xs text-fg-muted2">{p.matches} matches</p>
            </div>
          ))}
        </div>
      </section>

      {/* Host cities */}
      <section className="container-x mt-16">
        <h2 className="mb-4 font-display text-2xl font-bold">16 host cities</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
          {HOST_CITIES.map((h) => (
            <div key={h.stadium} className="panel p-4">
              <p className="text-sm font-bold text-fg">{h.city}</p>
              <p className="mt-0.5 text-xs text-fg-soft">{h.stadium}</p>
              <p className="mt-1 text-[11px] text-fg-muted2">{h.country}</p>
            </div>
          ))}
        </div>
      </section>

      <PlayCta slug={SLUG} headline="Follow every World Cup 2026 match live" />

      {/* FAQ */}
      <section className="container-x my-16">
        <h2 className="mb-4 font-display text-2xl font-bold">World Cup 2026 FAQ</h2>
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

function fmtRange(from: string, to: string): string {
  const f = new Date(from), t = new Date(to);
  const opt: Intl.DateTimeFormatOptions = { day: 'numeric', month: 'short', timeZone: 'UTC' };
  const fmt = (d: Date) => new Intl.DateTimeFormat('en-GB', opt).format(d);
  return from === to ? fmt(f) : `${fmt(f)} – ${fmt(t)}`;
}
