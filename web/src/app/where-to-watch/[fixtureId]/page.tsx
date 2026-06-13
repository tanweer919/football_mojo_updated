import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { SITE } from '@/lib/site';
import { getFixture, getBroadcasts } from '@/lib/api';
import { BroadcastExplorer } from './explorer';

export const revalidate = 600;

type Params = { params: { fixtureId: string } };

export async function generateMetadata({ params }: Params): Promise<Metadata> {
  const fx = await getFixture(params.fixtureId);
  if (!fx) return { title: 'Where to watch' };
  const match = `${fx.homeTeam.name} vs ${fx.awayTeam.name}`;
  const title = `${match} — Where to Watch (TV & Live Stream)`;
  const description = `Where to watch ${match} live: TV channels and streaming options by country for this World Cup 2026 fixture. Free broadcaster guide.`;
  return {
    title,
    description,
    alternates: { canonical: `/where-to-watch/${params.fixtureId}` },
    openGraph: { title: `${match} · Where to watch`, description, url: `${SITE.url}/where-to-watch/${params.fixtureId}` },
  };
}

export default async function FixtureWatchPage({ params }: Params) {
  const [fx, countries] = await Promise.all([
    getFixture(params.fixtureId),
    getBroadcasts(params.fixtureId),
  ]);
  if (!fx) notFound();

  const kickoff = new Date(fx.kickoffAt).toLocaleString('en-US', {
    weekday: 'long', day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit',
  });
  const total = countries.reduce((n, c) => n + c.broadcasters.length, 0);

  return (
    <div className="container-x py-12 sm:py-16">
      <Link href="/where-to-watch" className="text-sm text-fg-muted transition hover:text-gold">
        ← All fixtures
      </Link>

      {/* Match header */}
      <header className="panel mt-4 overflow-hidden">
        <div
          aria-hidden
          className="h-1 w-full bg-gradient-to-r from-gold-deep via-gold to-gold-deep"
        />
        <div className="p-6 sm:p-8">
          {fx.competition && <p className="eyebrow">{fx.competition.name}</p>}
          <div className="mt-4 flex items-center justify-center gap-5 sm:gap-10">
            <TeamBadge name={fx.homeTeam.name} crest={fx.homeTeam.crestUrl} />
            <div className="text-center">
              <div className="font-display text-2xl font-extrabold text-fg-muted">VS</div>
            </div>
            <TeamBadge name={fx.awayTeam.name} crest={fx.awayTeam.crestUrl} />
          </div>
          <p className="mt-5 text-center text-sm text-fg-soft">{kickoff}</p>
        </div>
      </header>

      <h1 className="mt-10 font-display text-2xl font-bold sm:text-3xl">
        Where to watch {fx.homeTeam.name} vs {fx.awayTeam.name}
      </h1>
      <p className="mt-2 text-fg-soft">
        {total > 0
          ? `${total} broadcasters across ${countries.length} countries. Search for yours.`
          : 'Broadcast listings for this match aren’t available yet — check back closer to kickoff.'}
      </p>

      <div className="mt-8">
        {countries.length > 0 ? (
          <BroadcastExplorer countries={countries} />
        ) : (
          <div className="panel p-8 text-center text-fg-muted">
            No broadcasters listed yet.{' '}
            <a href={SITE.playStoreUrl} className="text-gold hover:underline">Get the app</a> for live alerts.
          </div>
        )}
      </div>
    </div>
  );
}

function TeamBadge({ name, crest }: { name: string; crest: string | null }) {
  return (
    <div className="flex w-28 flex-col items-center gap-2 sm:w-36">
      {crest
        ? // eslint-disable-next-line @next/next/no-img-element
          <img src={crest} alt="" width={56} height={56} className="h-12 w-12 object-contain sm:h-14 sm:w-14" />
        : <div className="grid h-12 w-12 place-items-center rounded-full bg-surface-2 text-fg-muted sm:h-14 sm:w-14">{name.slice(0, 3)}</div>}
      <span className="text-center text-sm font-bold text-fg">{name}</span>
    </div>
  );
}
