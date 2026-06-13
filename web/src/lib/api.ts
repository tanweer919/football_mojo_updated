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

/** 🇮🇳 from "IN" — Regional Indicator Symbols, no flag assets needed. */
export function flagEmoji(code: string): string {
  if (!code || code.length !== 2) return '🌐';
  const cc = code.toUpperCase();
  const a = cc.charCodeAt(0), b = cc.charCodeAt(1);
  if (a < 65 || a > 90 || b < 65 || b > 90) return '🌐';
  return String.fromCodePoint(0x1f1e6 + (a - 65)) + String.fromCodePoint(0x1f1e6 + (b - 65));
}
