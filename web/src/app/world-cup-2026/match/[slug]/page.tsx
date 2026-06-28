import type { Metadata } from 'next';
import type { Fixture } from '@/lib/api';
import { getCompetitionFixtures } from '@/lib/api';
import { TeamCrest } from '@/components/team-crest';
import { WC, matchSlug } from '@/lib/wc';
import { pageMeta, breadcrumbLd, sportsEventLd } from '@/lib/seo';
import { Breadcrumbs, JsonLd, PlayCta } from '@/components/seo-bits';
import { ComingSoon } from '@/components/match-bits';
import { KickoffTime } from '@/components/kickoff-time';

export const revalidate = 300;
export const dynamicParams = true;

const FINISHED = new Set(['FINISHED', 'FT', 'AET', 'PEN']);

async function resolve(slug: string): Promise<Fixture | null> {
  const fixtures = await getCompetitionFixtures(WC.competitionNameMatch, WC.startDate, WC.endDate);
  return fixtures.find((f) => matchSlug(f.homeTeam.name, f.awayTeam.name, f.kickoffAt) === slug) ?? null;
}

export async function generateMetadata({ params }: { params: { slug: string } }): Promise<Metadata> {
  const f = await resolve(params.slug);
  if (!f) {
    return pageMeta({ title: 'World Cup 2026 Match', description: 'FIFA World Cup 2026 match details, live score and preview.', path: `/world-cup-2026/match/${params.slug}`, index: false });
  }
  const h = f.homeTeam.name, a = f.awayTeam.name;
  const done = FINISHED.has(f.status);
  return pageMeta({
    title: `${h} vs ${a} — World Cup 2026`,
    description: done
      ? `${h} ${f.homeScore}-${f.awayScore} ${a}: FIFA World Cup 2026 result, recap and stats. Free, no betting.`
      : `${h} vs ${a} at the FIFA World Cup 2026 — kick-off time, preview, head-to-head and live score. Free goal alerts in the app.`,
    path: `/world-cup-2026/match/${params.slug}`,
  });
}

export default async function WcMatch({ params }: { params: { slug: string } }) {
  const f = await resolve(params.slug);
  const crumbs = [
    { name: 'Home', path: '/' },
    { name: 'World Cup 2026', path: '/world-cup-2026' },
    { name: 'Fixtures', path: '/world-cup-2026/fixtures' },
    { name: f ? `${f.homeTeam.shortName ?? f.homeTeam.name} vs ${f.awayTeam.shortName ?? f.awayTeam.name}` : 'Match', path: `/world-cup-2026/match/${params.slug}` },
  ];

  if (!f) {
    return (
      <>
        <Breadcrumbs items={crumbs} />
        <ComingSoon title="Match not found yet" note="This fixture isn't in the schedule yet. Browse all World Cup 2026 fixtures, or check back closer to kick-off." />
      </>
    );
  }

  const done = FINISHED.has(f.status);
  const path = `/world-cup-2026/match/${params.slug}`;

  return (
    <>
      <JsonLd data={breadcrumbLd(crumbs)} />
      <JsonLd data={sportsEventLd({ home: f.homeTeam.name, away: f.awayTeam.name, startDate: f.kickoffAt, venue: f.venue, path })} />
      <Breadcrumbs items={crumbs} />

      <section className="container-x pt-8">
        <p className="eyebrow">FIFA World Cup 2026{f.venue ? ` · ${f.venue}` : ''}</p>
        <h1 className="mt-3 font-display text-3xl font-extrabold tracking-tight sm:text-4xl">
          {f.homeTeam.name} <span className="text-fg-muted">vs</span> {f.awayTeam.name}
        </h1>

        <div className="panel mt-6 flex items-center justify-center gap-6 p-8">
          <Side team={f.homeTeam} />
          <div className="text-center">
            {done || ['LIVE', 'HALF_TIME', '1H', '2H', 'HT'].includes(f.status) ? (
              <div className="font-mono text-4xl font-extrabold text-fg">{f.homeScore}–{f.awayScore}</div>
            ) : (
              <div className="font-mono text-lg text-fg-soft"><KickoffTime iso={f.kickoffAt} withDate /></div>
            )}
            <div className="mt-1 text-xs uppercase tracking-wide text-fg-muted2">{done ? 'Full time' : f.status}</div>
          </div>
          <Side team={f.awayTeam} />
        </div>

        <p className="mt-6 max-w-2xl text-base leading-relaxed text-fg-soft">
          {done
            ? `${f.homeTeam.name} ${f.homeScore}-${f.awayScore} ${f.awayTeam.name} — full FIFA World Cup 2026 result. Get the AI recap, stats and the rest of the bracket in the FootballMojo app.`
            : `${f.homeTeam.name} face ${f.awayTeam.name} at the FIFA World Cup 2026. Get the AI match preview, head-to-head and instant goal alerts in the free app.`}
        </p>
      </section>

      <PlayCta slug="world-cup-2026-match" headline={done ? 'Get the full AI recap & stats' : 'Get live alerts for this match'} />
    </>
  );
}

function Side({ team }: { team: Fixture['homeTeam'] }) {
  return (
    <div className="flex flex-1 flex-col items-center gap-2 text-center">
      <TeamCrest team={team} size={56} />
      <span className="text-sm font-bold text-fg">{team.name}</span>
    </div>
  );
}
