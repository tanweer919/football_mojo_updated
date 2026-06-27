import type { Metadata } from 'next';
import type { Fixture } from '@/lib/api';
import { getCompetitionFixtures } from '@/lib/api';
import { WC } from '@/lib/wc';
import { pageMeta, breadcrumbLd } from '@/lib/seo';
import { Breadcrumbs, JsonLd, PlayCta } from '@/components/seo-bits';
import { WcSubnav } from '@/components/wc-subnav';
import { TeamCrest } from '@/components/team-crest';
import { KickoffTime } from '@/components/kickoff-time';

export const revalidate = 300;
const PATH = '/world-cup-2026/bracket';

export const metadata: Metadata = pageMeta({
  title: 'World Cup 2026 Bracket — Knockout Tree',
  description:
    'The full FIFA World Cup 2026 knockout bracket — Round of 32 through the final. See confirmed teams and results as they happen. Free, no betting.',
  path: PATH,
});

const ROUNDS = [
  { key: 'R32', label: 'Round of 32', slots: 16, re: /32/ },
  { key: 'R16', label: 'Round of 16', slots: 8, re: /(^|_)16/ },
  { key: 'QF', label: 'Quarter-finals', slots: 4, re: /QUARTER|(^|_)QF/i },
  { key: 'SF', label: 'Semi-finals', slots: 2, re: /SEMI|(^|_)SF/i },
  { key: 'F', label: 'Final', slots: 1, re: /FINAL/i },
] as const;

const FINISHED = new Set(['FINISHED', 'FT', 'AET', 'PEN']);

export default async function BracketPage() {
  const fixtures = await getCompetitionFixtures(WC.competitionNameMatch, '2026-06-28', WC.endDate);
  const knockout = fixtures.filter((f) => f.stage && !/^GROUP/i.test(f.stage));
  const byRound = (re: RegExp) => knockout.filter((f) => re.test(f.stage ?? '')).sort((a, b) => a.kickoffAt.localeCompare(b.kickoffAt));
  const anyConfirmed = knockout.length > 0;

  const crumbs = [
    { name: 'Home', path: '/' },
    { name: 'World Cup 2026', path: '/world-cup-2026' },
    { name: 'Bracket', path: PATH },
  ];

  return (
    <>
      <JsonLd data={breadcrumbLd(crumbs)} />
      <WcSubnav />
      <Breadcrumbs items={crumbs} />

      <section className="container-x pt-8">
        <p className="eyebrow">FIFA World Cup 2026 · Knockouts</p>
        <h1 className="mt-3 font-display text-4xl font-extrabold tracking-tight sm:text-5xl">
          World Cup 2026 <span className="text-gold-grad">Bracket</span>
        </h1>
        <p className="mt-4 max-w-2xl text-base leading-relaxed text-fg-soft">
          The full knockout tree — Round of 32 to the final on 19 July in New York. Confirmed teams
          and results fill in live as the bracket takes shape. Predict the whole thing in the app.
        </p>
        {!anyConfirmed && (
          <div className="mt-6 rounded-xl border border-gold/30 bg-gold/5 px-5 py-4 text-sm text-fg-soft">
            The Round of 32 is confirmed after the group stage ends on <strong>27 June</strong> — the
            bracket below fills in automatically as ties are set (knockouts begin <strong>28 June</strong>).
          </div>
        )}
      </section>

      {/* Horizontal bracket — scrolls on small screens */}
      <div className="mt-10 overflow-x-auto pb-6">
        <div className="container-x flex min-w-[1100px] gap-4">
          {ROUNDS.map((round) => {
            const matches = byRound(round.re);
            const cells = matches.length ? matches : Array.from({ length: round.slots }, () => null);
            return (
              <div key={round.key} className="flex min-w-[210px] flex-1 flex-col">
                <h2 className="mb-3 text-center text-xs font-bold uppercase tracking-wide text-gold">{round.label}</h2>
                <div className="flex flex-1 flex-col justify-around gap-3">
                  {cells.map((m, i) => <BracketMatch key={m?.id ?? `${round.key}-${i}`} f={m} />)}
                </div>
              </div>
            );
          })}
        </div>
      </div>

      <PlayCta slug="world-cup-2026-bracket" headline="Predict the entire World Cup 2026 bracket" />
    </>
  );
}

function BracketMatch({ f }: { f: Fixture | null }) {
  if (!f) {
    return (
      <div className="rounded-lg border border-dashed border-border-soft bg-surface-1/30 px-3 py-2.5">
        <Slot /><div className="my-1 h-px bg-border-soft/60" /><Slot />
      </div>
    );
  }
  const done = FINISHED.has(f.status);
  return (
    <div className="rounded-lg border border-border bg-surface-1/70 px-3 py-2 shadow-card">
      <TeamRow team={f.homeTeam} score={done ? f.homeScore : null} winner={done && f.homeScore > f.awayScore} />
      <div className="my-1 h-px bg-border-soft/60" />
      <TeamRow team={f.awayTeam} score={done ? f.awayScore : null} winner={done && f.awayScore > f.homeScore} />
      {!done && (
        <p className="mt-1.5 text-center text-[10px] font-mono text-fg-muted2"><KickoffTime iso={f.kickoffAt} withDate /></p>
      )}
    </div>
  );
}

function TeamRow({ team, score, winner }: { team: Fixture['homeTeam']; score: number | null; winner: boolean }) {
  return (
    <div className="flex items-center gap-2">
      <TeamCrest team={team} size={18} />
      <span className={`flex-1 truncate text-sm ${winner ? 'font-bold text-fg' : 'font-medium text-fg-soft'}`}>
        {team.shortName ?? team.name}
      </span>
      {score !== null && <span className={`font-mono text-sm ${winner ? 'font-bold text-fg' : 'text-fg-muted'}`}>{score}</span>}
    </div>
  );
}

function Slot() {
  return (
    <div className="flex items-center gap-2">
      <span className="h-[18px] w-[18px] shrink-0 rounded-sm bg-surface-2" />
      <span className="text-sm text-fg-muted2">To be confirmed</span>
    </div>
  );
}
