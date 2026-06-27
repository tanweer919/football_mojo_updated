import Link from 'next/link';
import type { Fixture, Group, StandingRow } from '@/lib/api';
import { matchSlug } from '@/lib/wc';
import { KickoffTime } from '@/components/kickoff-time';
import { TeamCrest } from '@/components/team-crest';

const FINISHED = new Set(['FINISHED', 'FT', 'AET', 'PEN']);
const LIVE = new Set(['LIVE', 'HALF_TIME', '1H', '2H', 'HT', 'ET', 'P']);

/** One fixture as a compact, linkable row. Links to the per-match SEO page. */
export function FixtureRow({ f }: { f: Fixture }) {
  const finished = FINISHED.has(f.status);
  const live = LIVE.has(f.status);
  const href = `/world-cup-2026/match/${matchSlug(f.homeTeam.name, f.awayTeam.name, f.kickoffAt)}`;
  return (
    <Link
      href={href}
      className="flex items-center gap-3 rounded-xl border border-border-soft bg-surface-1/50 px-4 py-3 transition hover:border-gold/40"
    >
      <div className="flex flex-1 items-center justify-end gap-2 text-right">
        <span className="truncate text-sm font-semibold text-fg">{f.homeTeam.shortName ?? f.homeTeam.name}</span>
        <TeamCrest team={f.homeTeam} size={20} />
      </div>
      <div className="shrink-0 px-2 text-center">
        {finished || live ? (
          <span className={`font-mono text-sm font-bold ${live ? 'text-live' : 'text-fg'}`}>
            {f.homeScore}–{f.awayScore}
          </span>
        ) : (
          <span className="font-mono text-xs text-fg-muted"><KickoffTime iso={f.kickoffAt} /></span>
        )}
        {live && <span className="mt-0.5 block text-[9px] font-bold uppercase tracking-wide text-live">Live</span>}
      </div>
      <div className="flex flex-1 items-center gap-2">
        <TeamCrest team={f.awayTeam} size={20} />
        <span className="truncate text-sm font-semibold text-fg">{f.awayTeam.shortName ?? f.awayTeam.name}</span>
      </div>
    </Link>
  );
}

export function FixtureList({ fixtures }: { fixtures: Fixture[] }) {
  return (
    <div className="grid gap-2.5 sm:grid-cols-2">
      {fixtures.map((f) => <FixtureRow key={f.id} f={f} />)}
    </div>
  );
}

/** A single group standings table. */
export function GroupTable({ group }: { group: Group }) {
  return (
    <div className="panel overflow-hidden">
      <div className="flex items-center justify-between border-b border-border-soft px-4 py-3">
        <h3 className="font-display text-base font-bold text-fg">{group.name}</h3>
        <Link
          href={`/world-cup-2026/groups/${group.letter.toLowerCase()}`}
          className="text-xs font-medium text-gold transition hover:text-gold-soft"
        >
          Details →
        </Link>
      </div>
      <table className="w-full text-sm">
        <thead>
          <tr className="text-[10px] uppercase tracking-wide text-fg-muted2">
            <th className="px-4 py-2 text-left font-semibold">Team</th>
            <th className="px-1.5 py-2 text-center font-semibold" title="Played">P</th>
            <th className="px-1.5 py-2 text-center font-semibold" title="Won">W</th>
            <th className="px-1.5 py-2 text-center font-semibold" title="Drawn">D</th>
            <th className="px-1.5 py-2 text-center font-semibold" title="Lost">L</th>
            <th className="px-1.5 py-2 text-center font-semibold" title="Goal difference">GD</th>
            <th className="px-2 py-2 text-center font-bold text-fg-soft" title="Points">Pts</th>
          </tr>
        </thead>
        <tbody>
          {group.standings.map((r: StandingRow) => (
            <tr key={r.team.id} className="border-t border-border-soft/60">
              <td className="px-4 py-2">
                <span className="flex items-center gap-2">
                  <span className="w-4 text-fg-muted2">{r.position}</span>
                  <TeamCrest team={r.team} size={18} />
                  <span className="font-medium text-fg">{r.team.shortName ?? r.team.name}</span>
                </span>
              </td>
              <td className="px-1.5 py-2 text-center text-fg-soft">{r.played}</td>
              <td className="px-1.5 py-2 text-center text-fg-soft">{r.won}</td>
              <td className="px-1.5 py-2 text-center text-fg-soft">{r.drawn}</td>
              <td className="px-1.5 py-2 text-center text-fg-soft">{r.lost}</td>
              <td className="px-1.5 py-2 text-center text-fg-soft">{r.goalDiff > 0 ? `+${r.goalDiff}` : r.goalDiff}</td>
              <td className="px-2 py-2 text-center font-bold text-fg">{r.points}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

/** Graceful, noindex-friendly empty state — never render a thin live page. */
export function ComingSoon({ title, note }: { title: string; note: string }) {
  return (
    <div className="panel mx-auto my-16 max-w-xl p-10 text-center">
      <p className="eyebrow justify-center">Coming soon</p>
      <h2 className="mt-3 font-display text-2xl font-bold text-fg">{title}</h2>
      <p className="mt-3 text-sm leading-relaxed text-fg-muted">{note}</p>
    </div>
  );
}
