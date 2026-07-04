import type { Fixture } from '@/lib/api';
import { WC_BRACKET, WC_FEED, prettyTeamName, type BracketColumn } from '@/lib/wc';
import { TeamCrest } from '@/components/team-crest';
import { KickoffTime } from '@/components/kickoff-time';

const FINISHED = new Set(['FINISHED', 'FT', 'AET', 'PEN']);
const LIVE = new Set(['LIVE', 'HALF_TIME', '1H', '2H', 'HT', 'ET', 'BT', 'P']);

const H = 660;        // fixed tree height → deterministic 1/2^n slot fractions
const GAP = 30;       // horizontal gap between columns (connectors live here)
const HALF = GAP / 2; // where the vertical connector sits (gap midpoint)
const LINE = 'rgba(120,120,128,0.45)';

type Resolver = (n: number) => Fixture | null;

/** The full two-sided knockout bracket with elbow connectors. */
export function BracketTree({ resolver }: { resolver: Resolver }) {
  const finalFx = resolver(WC_BRACKET.final);
  const champion = winnerTeam(finalFx);

  return (
    <div className="overflow-x-auto pb-10">
      <div className="mx-auto w-max px-3 sm:px-5">
        <div className="flex items-stretch" style={{ height: H, columnGap: GAP }}>
          {WC_BRACKET.left.map((col, i) => (
            <Column key={`L${i}`} col={col} side="left" resolver={resolver} />
          ))}

          {/* Final + bronze, centre */}
          <div className="flex w-[168px] flex-col justify-center">
            <div className="mb-2 text-center text-xl">🏆</div>
            <h3 className="mb-2 text-center text-[11px] font-bold uppercase tracking-[0.15em] text-gold">Final</h3>
            <div className="relative">
              <Connector kind="in" side="left" />
              <Connector kind="in" side="right" />
              <MatchBox f={finalFx} slot={WC_BRACKET.final} emphasis />
            </div>
            {champion && (
              <p className="mt-2 text-center text-[11px] font-bold uppercase tracking-wide text-gold">
                {champion} — champions
              </p>
            )}
            <p className="mt-1 text-center text-[10px] uppercase tracking-wide text-fg-muted2">New York · 19 Jul</p>

            <div className="mt-8">
              <h3 className="mb-2 text-center text-[10px] font-bold uppercase tracking-[0.15em] text-fg-muted2">3rd place</h3>
              <MatchBox f={resolver(WC_BRACKET.bronze)} slot={WC_BRACKET.bronze} dim />
            </div>
          </div>

          {WC_BRACKET.right.map((col, i) => (
            <Column key={`R${i}`} col={col} side="right" resolver={resolver} />
          ))}
        </div>
      </div>
    </div>
  );
}

function Column({ col, side, resolver }: { col: BracketColumn; side: 'left' | 'right'; resolver: Resolver }) {
  const isLeaf = col.round === 'Round of 32';
  const isRoot = col.round === 'Semi-finals';
  return (
    <div className="flex w-[150px] flex-col">
      <h3 className="mb-1 h-6 text-center text-[11px] font-bold uppercase tracking-wide text-gold">{col.round}</h3>
      <div className="flex flex-1 flex-col">
        {col.nums.map((n, i) => (
          <div key={n} className="relative flex flex-1 items-center">
            {/* incoming line (from feeders) */}
            {!isLeaf && <Connector kind="in" side={side} />}
            {/* outgoing elbow (to the next round). Root SF is single → straight stub. */}
            <Connector kind="out" side={side} pos={isRoot ? 'single' : i % 2 === 0 ? 'top' : 'bottom'} />
            <div className="w-full">
              <MatchBox f={resolver(n)} slot={n} />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

/** A single connector segment set (in-stub, or out-stub + half-vertical). */
function Connector({
  kind, side, pos,
}: { kind: 'in' | 'out'; side: 'left' | 'right'; pos?: 'top' | 'bottom' | 'single' }) {
  const edge = side === 'left' ? 'right' : 'left';
  const opp = side === 'left' ? 'left' : 'right';

  if (kind === 'in') {
    // horizontal from this box's outer edge back to the gap midpoint
    return <span className="pointer-events-none absolute top-1/2 h-px" style={{ [opp]: -HALF, width: HALF, background: LINE }} />;
  }
  // out: horizontal stub to the gap midpoint …
  const horiz = <span className="pointer-events-none absolute top-1/2 h-px" style={{ [edge]: -HALF, width: HALF, background: LINE }} />;
  if (pos === 'single') return horiz;
  // … plus the vertical half that joins this box's sibling into one elbow.
  const vertical = (
    <span
      className="pointer-events-none absolute w-px"
      style={{
        [edge]: -HALF,
        width: 1,
        background: LINE,
        ...(pos === 'top' ? { top: '50%', height: '50%' } : { bottom: '50%', height: '50%' }),
      }}
    />
  );
  return <>{horiz}{vertical}</>;
}

function MatchBox({ f, slot, emphasis = false, dim = false }: { f: Fixture | null; slot: number; emphasis?: boolean; dim?: boolean }) {
  const base = 'relative rounded-lg border px-2 py-1.5 transition ';
  if (!f) {
    const feed = WC_FEED[slot];
    const labels: [string, string] = feed ? [prettyTeamName(feed[0]), prettyTeamName(feed[1])] : ['TBC', 'TBC'];
    return (
      <div className={base + (emphasis ? 'border-dashed border-gold/40 bg-gold/[0.06]' : 'border-dashed border-border-soft/70 bg-surface-1/20')}>
        <PlaceholderRow label={labels[0]} />
        <div className="my-1 h-px bg-border-soft/50" />
        <PlaceholderRow label={labels[1]} />
      </div>
    );
  }

  const done = FINISHED.has(f.status);
  const live = LIVE.has(f.status);
  const hp = f.homePenalties ?? 0, ap = f.awayPenalties ?? 0;
  const pens = f.homePenalties != null && f.awayPenalties != null && (hp > 0 || ap > 0);
  const homeWin = done && (f.homeScore > f.awayScore || (f.homeScore === f.awayScore && hp > ap));
  const awayWin = done && (f.awayScore > f.homeScore || (f.homeScore === f.awayScore && ap > hp));

  const shell = emphasis
    ? 'border-gold/60 bg-gold/[0.08] shadow-[0_0_24px_-6px_rgba(229,194,107,0.5)]'
    : dim
    ? 'border-border-soft/70 bg-surface-1/40'
    : 'border-border bg-surface-1/70 hover:border-gold/30';

  return (
    <div className={base + shell}>
      {live && <span className="absolute -top-1 right-1.5 h-2 w-2 animate-pulse rounded-full bg-live ring-2 ring-bg-deep" />}
      <TeamRow team={f.homeTeam} score={done ? f.homeScore : null} winner={homeWin} />
      <div className="my-1 h-px bg-border-soft/50" />
      <TeamRow team={f.awayTeam} score={done ? f.awayScore : null} winner={awayWin} />
      {pens && <p className="mt-1 text-center text-[9px] font-mono font-bold text-gold">pens {hp}–{ap}</p>}
      {!done && !live && <p className="mt-1 text-center text-[9px] font-mono text-fg-muted2"><KickoffTime iso={f.kickoffAt} withDate /></p>}
      {live && <p className="mt-1 text-center text-[9px] font-mono font-bold text-live">LIVE</p>}
    </div>
  );
}

function TeamRow({ team, score, winner }: { team: Fixture['homeTeam']; score: number | null; winner: boolean }) {
  return (
    <div className="flex items-center gap-1.5">
      <TeamCrest team={team} size={16} />
      <span className={`flex-1 truncate text-xs ${winner ? 'font-extrabold text-fg' : 'font-medium text-fg-soft'}`}>
        {team.shortName ?? team.name}
      </span>
      {score !== null && <span className={`font-mono text-xs tabular-nums ${winner ? 'font-extrabold text-gold' : 'text-fg-muted'}`}>{score}</span>}
    </div>
  );
}

function PlaceholderRow({ label }: { label: string }) {
  return (
    <div className="flex items-center gap-1.5">
      <span className="h-[16px] w-[16px] shrink-0 rounded-sm bg-surface-2/70" />
      <span className="truncate text-xs text-fg-muted2">{label}</span>
    </div>
  );
}

function winnerTeam(f: Fixture | null): string | null {
  if (!f || !FINISHED.has(f.status)) return null;
  const hp = f.homePenalties ?? 0, ap = f.awayPenalties ?? 0;
  if (f.homeScore > f.awayScore || (f.homeScore === f.awayScore && hp > ap)) return f.homeTeam.shortName ?? f.homeTeam.name;
  if (f.awayScore > f.homeScore || (f.homeScore === f.awayScore && ap > hp)) return f.awayTeam.shortName ?? f.awayTeam.name;
  return null;
}
