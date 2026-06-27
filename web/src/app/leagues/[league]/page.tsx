import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { pageMeta, breadcrumbLd } from '@/lib/seo';
import { getCompetitionFixtures } from '@/lib/api';
import { LEAGUES, leagueBySlug } from '@/lib/leagues';
import { Breadcrumbs, JsonLd, PlayCta } from '@/components/seo-bits';
import { FixtureList, FixtureGroups } from '@/components/match-bits';

export const revalidate = 600;
export const dynamicParams = false;

export function generateStaticParams() {
  return LEAGUES.map((l) => ({ league: l.slug }));
}

export async function generateMetadata({ params }: { params: { league: string } }): Promise<Metadata> {
  const l = leagueBySlug(params.league);
  if (!l) return pageMeta({ title: 'Football', description: 'Live football scores and fixtures.', path: `/leagues/${params.league}`, index: false });
  return pageMeta({
    title: `${l.short} Fixtures, Live Scores & Table`,
    description: `${l.name} fixtures, live scores, results and standings — free, with no betting. AI match previews and recaps in the FootballMojo app.`,
    path: `/leagues/${l.slug}`,
  });
}

export default async function LeaguePage({ params }: { params: { league: string } }) {
  const l = leagueBySlug(params.league);
  if (!l) notFound();

  const today = new Date();
  const from = new Date(today.getTime() - 3 * 86_400_000).toISOString().slice(0, 10);
  const to = new Date(today.getTime() + 30 * 86_400_000).toISOString().slice(0, 10);
  const fixtures = await getCompetitionFixtures(l.nameMatch, from, to);
  const recent = fixtures.filter((f) => ['FINISHED', 'FT', 'AET', 'PEN'].includes(f.status)).slice(-6).reverse();
  const upcoming = fixtures.filter((f) => f.status === 'SCHEDULED').slice(0, 10);

  const crumbs = [
    { name: 'Home', path: '/' },
    { name: l.name, path: `/leagues/${l.slug}` },
  ];

  return (
    <>
      <JsonLd data={breadcrumbLd(crumbs)} />
      <Breadcrumbs items={crumbs} />
      <section className="container-x pt-8">
        <p className="eyebrow">Live football{l.region ? ` · ${l.region}` : ''}</p>
        <h1 className="mt-3 font-display text-4xl font-extrabold tracking-tight sm:text-5xl">
          {l.short} <span className="text-gold-grad">Fixtures, Live Scores &amp; Table</span>
        </h1>
        <p className="mt-4 max-w-2xl text-base leading-relaxed text-fg-soft">{l.blurb}</p>
      </section>

      <div className="container-x mt-10 space-y-10">
        {recent.length > 0 && (
          <section>
            <h2 className="mb-3 font-display text-xl font-bold">Latest results</h2>
            <FixtureList fixtures={recent} />
          </section>
        )}
        {upcoming.length > 0 && (
          <section>
            <h2 className="mb-3 font-display text-xl font-bold">Upcoming fixtures</h2>
            <FixtureGroups fixtures={upcoming} />
          </section>
        )}
        {recent.length === 0 && upcoming.length === 0 && (
          <p className="text-sm leading-relaxed text-fg-muted">
            Fixtures and live scores for the {l.name} appear here through the season. Get instant goal
            alerts, AI match previews and the full table in the free FootballMojo app — no betting,
            no gambling.
          </p>
        )}
      </div>

      <PlayCta slug={`league-${l.slug}`} headline={`Follow the ${l.short} live`} />
    </>
  );
}
