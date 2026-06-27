/**
 * Server-side data access for the public site. Talks to the FootballMojo
 * backend's unauthenticated endpoints (scores + insights/broadcasts). All
 * calls use ISR so pages are static-fast yet refresh on a cadence.
 */
const API_BASE = process.env.API_URL ?? 'https://api.footballmojo.in/api/v1';

export interface Team {
  id: string;
  name: string;
  shortName: string | null;
  crestUrl: string | null;
  countryCode: string | null;
}
export interface Fixture {
  id: string;
  kickoffAt: string;
  status: string;
  homeScore: number;
  awayScore: number;
  homeTeam: Team;
  awayTeam: Team;
  competition: { id: string; name: string } | null;
  stage?: string | null;  // GROUP_A | ROUND_OF_32 | ROUND_OF_16 | QUARTER | SEMI | FINAL
  venue?: string | null;
}
export interface Broadcaster {
  name: string;
  url: string | null;
  logo: string | null;
}
export interface CountryBroadcast {
  country: string; // ISO-2 ('' = worldwide)
  countryName: string;
  broadcasters: Broadcaster[];
}

async function get<T>(path: string, revalidate: number): Promise<T | null> {
  try {
    const res = await fetch(`${API_BASE}${path}`, { next: { revalidate } });
    if (!res.ok) return null;
    return (await res.json()) as T;
  } catch {
    return null;
  }
}

const day = (d: Date) => d.toISOString().slice(0, 10);

/** Upcoming fixtures from today through `+days` (default 14). */
export async function getUpcomingFixtures(days = 14): Promise<Fixture[]> {
  const from = new Date();
  const to = new Date(Date.now() + days * 86_400_000);
  const rows = await get<Fixture[]>(`/scores/fixtures/range?from=${day(from)}&to=${day(to)}`, 600);
  return rows ?? [];
}

export async function getFixture(id: string): Promise<Fixture | null> {
  return get<Fixture>(`/scores/matches/${id}`, 300);
}

export async function getBroadcasts(fixtureId: string): Promise<CountryBroadcast[]> {
  const rows = await get<CountryBroadcast[]>(`/insights/broadcasts/${fixtureId}`, 600);
  return rows ?? [];
}

// ── Group standings ──────────────────────────────────────────────────────────
export interface StandingRow {
  position: number;
  team: { id: string; name: string; shortName: string | null; countryCode: string | null; crestUrl: string | null };
  played: number;
  won: number;
  drawn: number;
  lost: number;
  goalsFor: number;
  goalsAgainst: number;
  goalDiff: number;
  points: number;
}
export interface Group {
  id: string;
  name: string;   // "Group A"
  letter: string; // "A"
  standings: StandingRow[];
}

/** Group tables for a competition (computed from results on the backend). */
export async function getGroups(competitionId: string): Promise<Group[]> {
  const rows = await get<Group[]>(`/competitions/${competitionId}/groups`, 300);
  return rows ?? [];
}

/** Fixtures in [from,to] for one competition (by name match), sorted by kickoff. */
export async function getCompetitionFixtures(
  competitionNameMatch: RegExp,
  from: string,
  to: string,
): Promise<Fixture[]> {
  const rows = await get<Fixture[]>(`/scores/fixtures/range?from=${from}&to=${to}`, 600);
  return (rows ?? [])
    .filter((f) => f.competition != null && competitionNameMatch.test(f.competition.name))
    .sort((a, b) => a.kickoffAt.localeCompare(b.kickoffAt));
}

/** 🇮🇳 from "IN" — Regional Indicator Symbols, no flag assets needed. */
export function flagEmoji(code: string): string {
  if (!code || code.length !== 2) return '🌐';
  const cc = code.toUpperCase();
  const a = cc.charCodeAt(0), b = cc.charCodeAt(1);
  if (a < 65 || a > 90 || b < 65 || b > 90) return '🌐';
  return String.fromCodePoint(0x1f1e6 + (a - 65)) + String.fromCodePoint(0x1f1e6 + (b - 65));
}
