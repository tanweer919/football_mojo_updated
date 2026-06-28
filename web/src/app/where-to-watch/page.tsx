import type { Metadata } from 'next';
import Link from 'next/link';
import { SITE } from '@/lib/site';
import { getUpcomingFixtures, type Fixture } from '@/lib/api';

export const metadata: Metadata = {
  title: 'Where to Watch — World Cup 2026 TV & Streaming Guide',
  description:
    'Find out where to watch every FIFA World Cup 2026 match — TV channels and live streams for your country, free. Full fixture-by-fixture broadcaster guide.',
  alternates: { canonical: '/where-to-watch' },
  openGraph: {
    title: 'Where to Watch the World Cup 2026 · FootballMojo',
    description: 'TV channels and live streams for every World Cup 2026 fixture, by country — free.',
    url: `${SITE.url}/where-to-watch`,
  },
};

export const revalidate = 600;

function groupByDate(fixtures: Fixture[]): [string, Fixture[]][] {
  const map = new Map<string, Fixture[]>();
  for (const f of fixtures) {
    const key = new Date(f.kickoffAt).toLocaleDateString('en-US', {
      weekday: 'long', day: 'numeric', month: 'long',
    });
    (map.get(key) ?? map.set(key, []).get(key)!).push(f);
  }
  return [...map.entries()];
}

function kickoff(iso: string) {
  return new Date(iso).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
}

const FINISHED = new Set(['FINISHED', 'FT', 'AET', 'PEN']);

export default async function WhereToWatchPage() {
  const all = await getUpcomingFixtures(14);
  // Only forward-looking matches: drop anything finished or already kicked off
  // (the day-range query can include earlier-today / timezone-spillover games).
  // The 2h grace keeps matches currently in progress.
  const now = Date.now();
  const fixtures = all.filter(
    (f) => !FINISHED.has(f.status) && new Date(f.kickoffAt).getTime() > now - 2 * 3_600_000,
  );
  const groups = groupByDate(fixtures);

  return (
    <div className="container-x py-14 sm:py-20">
      {/* Hero */}
      <header className="relative">
        <div
          aria-hidden
          className="pointer-events-none absolute -top-24 left-1/2 -z-10 h-72 w-72 -translate-x-1/2 rounded-full"
          style={{ background: 'radial-gradient(circle, rgba(229,194,107,0.16), transparent 70%)' }}
        />
        <p className="eyebrow">📺 Where to watch</p>
        <h1 className="mt-3 font-display text-4xl font-extrabold leading-[1.05] sm:text-5xl lg:text-6xl">
          Where to Watch World Cup 2026:
          <br />
          <span className="text-gold-grad">TV Channels &amp; Live Streams</span>
        </h1>
        <p className="mt-4 text-lg font-medium text-fg-soft">Every World Cup 2026 match, on every screen.</p>
        <p className="mt-4 max-w-2xl text-base leading-relaxed text-fg-soft">
          Find the TV channel or live stream for every FIFA World Cup 2026 fixture — in your country
          and 200+ others. Pick a match below for its broadcaster guide. Free, no sign-up, no betting.
          Hosted across the USA, Canada and Mexico, the 48-team tournament runs 11 June – 19 July 2026.
        </p>
      </header>

      {/* Fixtures */}
      <div className="mt-12 space-y-10">
        {groups.length === 0 && (
          <div className="panel p-8 text-center text-fg-muted">
            No upcoming fixtures right now — check back soon.
          </div>
        )}
        {groups.map(([date, day]) => (
          <section key={date}>
            <div className="mb-4 flex items-center gap-3">
              <h2 className="font-display text-lg font-bold text-fg">{date}</h2>
              <div className="hairline flex-1" />
              <span className="text-xs font-mono text-fg-muted">{day.length} {day.length === 1 ? 'match' : 'matches'}</span>
            </div>
            <div className="grid gap-3 sm:grid-cols-2">
              {day.map((f) => (
                <Link
                  key={f.id}
                  href={`/where-to-watch/${f.id}`}
                  className="panel group flex items-center gap-4 p-4 transition hover:-translate-y-0.5 hover:border-gold/30 hover:shadow-[0_8px_40px_rgba(229,194,107,0.10)]"
                >
                  <div className="w-14 shrink-0 text-center">
                    <div className="font-mono text-sm font-bold text-gold">{kickoff(f.kickoffAt)}</div>
                    {f.competition && (
                      <div className="mt-0.5 truncate text-[10px] uppercase tracking-wider text-fg-muted2">
                        {f.competition.name}
                      </div>
                    )}
                  </div>
                  <div className="hairline h-10 w-px" />
                  <div className="min-w-0 flex-1">
                    <TeamRow team={f.homeTeam} />
                    <TeamRow team={f.awayTeam} className="mt-1.5" />
                  </div>
                  <span className="shrink-0 text-fg-muted transition group-hover:text-gold">→</span>
                </Link>
              ))}
            </div>
          </section>
        ))}
      </div>

      <p className="mt-12 text-center text-xs text-fg-muted2">
        Broadcast listings are indicative and may change. Want it on your phone with live scores?{' '}
        <a href={SITE.playStoreUrl} className="text-gold hover:underline">Get the app</a>.
      </p>
    </div>
  );
}

function TeamRow({ team, className = '' }: { team: Fixture['homeTeam']; className?: string }) {
  return (
    <div className={`flex items-center gap-2.5 ${className}`}>
      {team.crestUrl
        ? // eslint-disable-next-line @next/next/no-img-element
          <img src={team.crestUrl} alt={`${team.name} crest`} width={20} height={20} className="h-5 w-5 object-contain" />
        : <span className="grid h-5 w-5 place-items-center rounded-full bg-surface-2 text-[9px] text-fg-muted">{team.shortName ?? '?'}</span>}
      <span className="truncate text-sm font-semibold text-fg">{team.name}</span>
    </div>
  );
}
