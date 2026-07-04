import type { Metadata } from 'next';
import type { Fixture } from '@/lib/api';
import { getCompetitionFixtures } from '@/lib/api';
import { WC, WC_R32, WC_FEED, WC_BRACKET, prettyTeamName, normNation } from '@/lib/wc';
import { pageMeta, breadcrumbLd } from '@/lib/seo';
import { Breadcrumbs, JsonLd, PlayCta } from '@/components/seo-bits';
import { WcSubnav } from '@/components/wc-subnav';
import { TeamCrest } from '@/components/team-crest';
import { KickoffTime } from '@/components/kickoff-time';

export const revalidate = 120;
const PATH = '/world-cup-2026/bracket';
const FINISHED = new Set(['FINISHED', 'FT', 'AET', 'PEN']);

export const metadata: Metadata = pageMeta({
  title: 'World Cup 2026 Bracket — Knockout Tree',
  description:
    'The full FIFA World Cup 2026 knockout bracket — Round of 32 through the final. Teams advance automatically as results land. Free, no betting.',
  path: PATH,
});

// ── Resolve each bracket slot from the fixtures ──────────────────────────────
function buildResolver(fixtures: Fixture[]) {
  const ko = fixtures.filter((f) => f.stage && !/group/i.test(f.stage));
  const key = (a: string, b: string) => [normNation(a), normNation(b)].sort().join('|');

  const fixtureByPair = new Map<string, Fixture>();
  for (const f of ko) fixtureByPair.set(key(f.homeTeam.name, f.awayTeam.name), f);

  const resultByPair = new Map<string, { w: string; l: string }>();
  for (const f of ko) {
    if (!FINISHED.has(f.status)) continue;
    const hn = normNation(f.homeTeam.name), an = normNation(f.awayTeam.name);
    let w = hn, l = an;
    if (f.homeScore < f.awayScore) { w = an; l = hn; }
    else if (f.homeScore === f.awayScore) {
      const hp = f.homePenalties ?? 0, ap = f.awayPenalties ?? 0;
      if (hp === ap) continue;
      if (hp < ap) { w = an; l = hn; }
    }
    resultByPair.set([hn, an].sort().join('|'), { w, l });
  }

  const teamsOf = new Map<number, [string, string]>();
  for (const [n, [h, a]] of Object.entries(WC_R32)) teamsOf.set(+n, [normNation(h), normNation(a)]);
  for (let n = 89; n <= 104; n++) {
    const feed = WC_FEED[n];
    if (!feed) continue;
    const res = (ref: string): string | undefined => {
      const tm = teamsOf.get(+ref.slice(1));
      if (!tm) return undefined;
      const r = resultByPair.get([tm[0], tm[1]].sort().join('|'));
      if (!r) return undefined;
      return ref[0] === 'W' ? r.w : r.l;
    };
    const h = res(feed[0]), a = res(feed[1]);
    if (h && a) teamsOf.set(n, [h, a]);
  }

  return (n: number): Fixture | null => {
    const tm = teamsOf.get(n);
    if (!tm) return null;
    return fixtureByPair.get([tm[0], tm[1]].sort().join('|')) ?? null;
  };
}

export default async function BracketPage() {
  const fixtures = await getCompetitionFixtures(WC.competitionNameMatch, '2026-06-28', WC.endDate);
  const fixtureForSlot = buildResolver(fixtures);
  const anyResolved = fixtures.some((f) => f.stage && !/group/i.test(f.stage) && FINISHED.has(f.status));

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
          The full knockout tree, split left and right toward the final in New York on 19 July.
          Winners advance automatically as each result comes in. Predict it in the app.
        </p>
        {!anyResolved && (
          <div className="mt-6 rounded-xl border border-gold/30 bg-gold/5 px-5 py-4 text-sm text-fg-soft">
            The Round of 32 is confirmed after the group stage ends on <strong>27 June</strong> — the
            bracket fills in automatically as ties are decided (knockouts begin <strong>28 June</strong>).
          </div>
        )}
      </section>

      {/* Two-sided bracket: left rounds → final → right rounds. Equal-height
          columns + justify-around keep each round centred against its feeders. */}
      <div className="mt-10 overflow-x-auto pb-8">
        <div className="mx-auto flex min-h-[720px] w-max items-stretch gap-x-4 px-3 sm:px-5">
          {WC_BRACKET.left.map((col, i) => (
            <Column key={`L${i}`} label={col.round} nums={col.nums} resolver={fixtureForSlot} stub="right" />
          ))}

          <div className="mx-2 flex w-[160px] flex-col justify-center px-1">
            <h2 className="mb-3 text-center text-[11px] font-bold uppercase tracking-wide text-gold">Final</h2>
            <Slot n={WC_BRACKET.final} resolver={fixtureForSlot} highlight />
            <p className="mt-2 text-center text-[10px] uppercase tracking-wide text-fg-muted2">New York · 19 Jul</p>
            <h2 className="mb-2 mt-6 text-center text-[10px] font-bold uppercase tracking-wide text-fg-muted2">3rd place</h2>
            <Slot n={WC_BRACKET.bronze} resolver={fixtureForSlot} />
          </div>

          {WC_BRACKET.right.map((col, i) => (
            <Column key={`R${i}`} label={col.round} nums={col.nums} resolver={fixtureForSlot} stub="left" />
          ))}
        </div>
      </div>

      <PlayCta slug="world-cup-2026-bracket" headline="Predict the entire World Cup 2026 bracket" />
    </>
  );
}

function Column({
  label, nums, resolver, stub,
}: { label: string; nums: number[]; resolver: (n: number) => Fixture | null; stub: 'left' | 'right' }) {
  return (
    <div className="flex w-[150px] flex-col">
      <h2 className="mb-3 text-center text-[11px] font-bold uppercase tracking-wide text-gold">{label}</h2>
      <div className="flex flex-1 flex-col justify-around">
        {nums.map((n) => <Slot key={n} n={n} resolver={resolver} stub={stub} />)}
      </div>
    </div>
  );
}

const STUB = {
  right: "relative after:absolute after:left-full after:top-1/2 after:h-px after:w-4 after:bg-border after:content-['']",
  left: "relative before:absolute before:right-full before:top-1/2 before:h-px before:w-4 before:bg-border before:content-['']",
  none: '',
} as const;

function Slot({
  n, resolver, stub = 'none', highlight = false,
}: { n: number; resolver: (n: number) => Fixture | null; stub?: 'left' | 'right' | 'none'; highlight?: boolean }) {
  const f = resolver(n);
  const wrap = `rounded-md border px-2 py-1.5 ${STUB[stub]} `;

  if (!f) {
    const feed = WC_FEED[n];
    const labels: [string, string] = feed ? [prettyTeamName(feed[0]), prettyTeamName(feed[1])] : ['TBC', 'TBC'];
    return (
      <div className={wrap + (highlight ? 'border-dashed border-gold/40 bg-gold/5' : 'border-dashed border-border-soft bg-surface-1/30')}>
        <PlaceholderRow label={labels[0]} />
        <div className="my-1 h-px bg-border-soft/60" />
        <PlaceholderRow label={labels[1]} />
      </div>
    );
  }

  const done = FINISHED.has(f.status);
  const hp = f.homePenalties ?? 0, ap = f.awayPenalties ?? 0;
  const pens = f.homePenalties != null && f.awayPenalties != null && (hp > 0 || ap > 0);
  const homeWin = done && (f.homeScore > f.awayScore || (f.homeScore === f.awayScore && hp > ap));
  const awayWin = done && (f.awayScore > f.homeScore || (f.homeScore === f.awayScore && ap > hp));

  return (
    <div className={wrap + (highlight ? 'border-gold/50 bg-gold/5 shadow-card' : 'border-border bg-surface-1/70')}>
      <TeamRow team={f.homeTeam} score={done ? f.homeScore : null} winner={homeWin} />
      <div className="my-1 h-px bg-border-soft/60" />
      <TeamRow team={f.awayTeam} score={done ? f.awayScore : null} winner={awayWin} />
      {pens && <p className="mt-1 text-center text-[9px] font-mono text-gold">pens {hp}-{ap}</p>}
      {!done && <p className="mt-1 text-center text-[9px] font-mono text-fg-muted2"><KickoffTime iso={f.kickoffAt} withDate /></p>}
    </div>
  );
}

function TeamRow({ team, score, winner }: { team: Fixture['homeTeam']; score: number | null; winner: boolean }) {
  return (
    <div className="flex items-center gap-1.5">
      <TeamCrest team={team} size={15} />
      <span className={`flex-1 truncate text-xs ${winner ? 'font-bold text-fg' : 'font-medium text-fg-soft'}`}>{team.shortName ?? team.name}</span>
      {score !== null && <span className={`font-mono text-xs ${winner ? 'font-bold text-fg' : 'text-fg-muted'}`}>{score}</span>}
    </div>
  );
}

function PlaceholderRow({ label }: { label: string }) {
  return (
    <div className="flex items-center gap-1.5">
      <span className="h-[15px] w-[15px] shrink-0 rounded-sm bg-surface-2" />
      <span className="truncate text-xs text-fg-muted2">{label}</span>
    </div>
  );
}
