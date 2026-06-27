import type { Metadata } from 'next';
import Link from 'next/link';
import { pageMeta, breadcrumbLd } from '@/lib/seo';
import { getCompetitionFixtures } from '@/lib/api';
import { WC } from '@/lib/wc';
import { Breadcrumbs, JsonLd, PlayCta } from '@/components/seo-bits';
import { FixtureList, ComingSoon } from '@/components/match-bits';
import { WcSubnav } from '@/components/wc-subnav';

export const revalidate = 600;
const PATH = '/world-cup-2026/fixtures';

export const metadata: Metadata = pageMeta({
  title: 'World Cup 2026 Fixtures — Full Match Schedule',
  description:
    'Every FIFA World Cup 2026 fixture by date — kick-off times in your timezone, live scores and results. Free, no betting. Browse the full schedule.',
  path: PATH,
});

export default async function WcFixtures() {
  const fixtures = await getCompetitionFixtures(WC.competitionNameMatch, WC.startDate, WC.endDate);
  const byDate = new Map<string, typeof fixtures>();
  for (const f of fixtures) {
    const d = f.kickoffAt.slice(0, 10);
    (byDate.get(d) ?? byDate.set(d, []).get(d)!).push(f);
  }
  const dates = [...byDate.keys()].sort();

  const crumbs = [
    { name: 'Home', path: '/' },
    { name: 'World Cup 2026', path: '/world-cup-2026' },
    { name: 'Fixtures', path: PATH },
  ];

  return (
    <>
      <JsonLd data={breadcrumbLd(crumbs)} />
      <WcSubnav />
      <Breadcrumbs items={crumbs} />
      <section className="container-x pt-8">
        <p className="eyebrow">FIFA World Cup 2026</p>
        <h1 className="mt-3 font-display text-4xl font-extrabold tracking-tight sm:text-5xl">
          World Cup 2026 <span className="text-gold-grad">Fixtures</span>
        </h1>
        <p className="mt-4 max-w-2xl text-base leading-relaxed text-fg-soft">
          The complete World Cup 2026 match schedule — all {WC.matchCount} fixtures across the group
          stage and knockouts. Kick-off times convert to your local timezone automatically.
        </p>
      </section>

      {dates.length === 0 ? (
        <ComingSoon title="Fixtures load as they're scheduled" note="The full schedule appears here automatically. Check back soon." />
      ) : (
        <div className="container-x mt-10 space-y-10">
          {dates.map((d) => (
            <section key={d}>
              <div className="mb-3 flex items-end justify-between">
                <h2 className="font-display text-xl font-bold">{longDate(d)}</h2>
                <Link href={`${PATH}/${d}`} className="text-sm font-medium text-gold transition hover:text-gold-soft">
                  Day page →
                </Link>
              </div>
              <FixtureList fixtures={byDate.get(d)!} />
            </section>
          ))}
        </div>
      )}

      <PlayCta slug="world-cup-2026-fixtures" />
    </>
  );
}

function longDate(d: string): string {
  return new Intl.DateTimeFormat('en-GB', { weekday: 'long', day: 'numeric', month: 'long', timeZone: 'UTC' }).format(new Date(d));
}
