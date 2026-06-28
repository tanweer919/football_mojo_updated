/**
 * Static, known-ahead-of-time World Cup 2026 tournament structure.
 *
 * Live/changing data (fixtures, scores, standings) comes from the backend via
 * `lib/api.ts`. This file holds only the facts that are fixed for the whole
 * tournament — format, dates, hosts, stadiums — so the SEO pages render real,
 * distinct content even before a given fixture has data.
 */

export const WC = {
  competitionId: 'WC2026',
  name: 'FIFA World Cup 2026',
  shortName: 'World Cup 2026',
  year: 2026,
  startDate: '2026-06-11',
  endDate: '2026-07-19',
  teamCount: 48,
  groupCount: 12,
  matchCount: 104,
  hosts: ['United States', 'Canada', 'Mexico'],
  // Used to filter the all-competitions fixtures feed down to the World Cup.
  competitionNameMatch: /world cup/i,
} as const;

/** Group letters A–L (12 groups of 4). */
export const GROUP_LETTERS = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L'] as const;
export type GroupLetter = (typeof GROUP_LETTERS)[number];

/** Tournament phases with their date windows (per the official schedule). */
export const WC_PHASES = [
  { key: 'group', label: 'Group stage', from: '2026-06-11', to: '2026-06-27', matches: 72 },
  { key: 'r32', label: 'Round of 32', from: '2026-06-28', to: '2026-07-03', matches: 16 },
  { key: 'r16', label: 'Round of 16', from: '2026-07-04', to: '2026-07-07', matches: 8 },
  { key: 'qf', label: 'Quarter-finals', from: '2026-07-09', to: '2026-07-11', matches: 4 },
  { key: 'sf', label: 'Semi-finals', from: '2026-07-14', to: '2026-07-15', matches: 2 },
  { key: 'final', label: 'Third place & Final', from: '2026-07-18', to: '2026-07-19', matches: 2 },
] as const;

/** 16 host cities across the three nations. */
export interface HostCity {
  city: string;
  country: 'USA' | 'Canada' | 'Mexico';
  stadium: string;
}
export const HOST_CITIES: HostCity[] = [
  { city: 'New York / New Jersey', country: 'USA', stadium: 'MetLife Stadium' },
  { city: 'Los Angeles', country: 'USA', stadium: 'SoFi Stadium' },
  { city: 'Dallas', country: 'USA', stadium: 'AT&T Stadium' },
  { city: 'San Francisco Bay Area', country: 'USA', stadium: "Levi's Stadium" },
  { city: 'Miami', country: 'USA', stadium: 'Hard Rock Stadium' },
  { city: 'Atlanta', country: 'USA', stadium: 'Mercedes-Benz Stadium' },
  { city: 'Seattle', country: 'USA', stadium: 'Lumen Field' },
  { city: 'Houston', country: 'USA', stadium: 'NRG Stadium' },
  { city: 'Philadelphia', country: 'USA', stadium: 'Lincoln Financial Field' },
  { city: 'Kansas City', country: 'USA', stadium: 'Arrowhead Stadium' },
  { city: 'Boston', country: 'USA', stadium: 'Gillette Stadium' },
  { city: 'Toronto', country: 'Canada', stadium: 'BMO Field' },
  { city: 'Vancouver', country: 'Canada', stadium: 'BC Place' },
  { city: 'Mexico City', country: 'Mexico', stadium: 'Estadio Azteca' },
  { city: 'Guadalajara', country: 'Mexico', stadium: 'Estadio Akron' },
  { city: 'Monterrey', country: 'Mexico', stadium: 'Estadio BBVA' },
];

/**
 * Make a knockout placeholder team name human-readable.
 * api-football / the seed use positional codes for undecided slots:
 *   "A1" → "Winner A", "B2" → "Runner-up B", "3rd A/B/C/D/F" → "3rd place A/B/C/D/F".
 * Real team names pass through unchanged.
 */
export function prettyTeamName(name: string): string {
  const m = name.match(/^([A-L])([12])$/);
  if (m) return `${m[2] === '1' ? 'Winner' : 'Runner-up'} ${m[1]}`;
  if (/^3rd\b/i.test(name)) return name.replace(/^3rd\s*/i, '3rd place ');
  // Knockout feed refs: W74 = winner of match 74, L101 = loser of match 101.
  const w = name.match(/^([WL])(\d{2,3})$/i);
  if (w) {
    const n = +w[2];
    const round = n <= 88 ? 'R32' : n <= 96 ? 'R16' : n <= 100 ? 'QF' : 'SF';
    return `${w[1].toUpperCase() === 'W' ? 'Winner' : 'Loser'} ${round}`;
  }
  return name;
}

/** A URL-safe match slug: "canada-vs-bosnia-and-herzegovina-2026-06-13". */
export function matchSlug(home: string, away: string, kickoffISO: string): string {
  const norm = (s: string) =>
    s.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '')
      .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
  const date = kickoffISO.slice(0, 10);
  return `${norm(home)}-vs-${norm(away)}-${date}`;
}
