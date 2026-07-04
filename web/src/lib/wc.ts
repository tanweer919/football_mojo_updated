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

// ── Knockout bracket structure ───────────────────────────────────────────────
// The bracket is a fixed tree (FIFA match numbers 73–104). We render from this
// structure — not from fixture array order — so every tie sits in its correct
// slot and half (e.g. a left-half team can only meet a right-half team in the
// final). Fixtures are matched into slots by team pair.

/** Round of 32 matchups by FIFA match number (official listing). */
export const WC_R32: Record<number, [string, string]> = {
  73: ['South Africa', 'Canada'], 74: ['Germany', 'Paraguay'], 75: ['Netherlands', 'Morocco'],
  76: ['Brazil', 'Japan'], 77: ['France', 'Sweden'], 78: ['Ivory Coast', 'Norway'],
  79: ['Mexico', 'Ecuador'], 80: ['England', 'DR Congo'], 81: ['United States', 'Bosnia and Herzegovina'],
  82: ['Belgium', 'Senegal'], 83: ['Portugal', 'Croatia'], 84: ['Spain', 'Austria'],
  85: ['Switzerland', 'Algeria'], 86: ['Argentina', 'Cape Verde'], 87: ['Colombia', 'Ghana'],
  88: ['Australia', 'Egypt'],
};

/** Feed tree: match number → its two feeders. "W74" = winner of 74, "L101" = loser of 101. */
export const WC_FEED: Record<number, [string, string]> = {
  89: ['W74', 'W77'], 90: ['W73', 'W75'], 91: ['W76', 'W78'], 92: ['W79', 'W80'],
  93: ['W83', 'W84'], 94: ['W81', 'W82'], 95: ['W86', 'W88'], 96: ['W85', 'W87'],
  97: ['W89', 'W90'], 98: ['W93', 'W94'], 99: ['W91', 'W92'], 100: ['W95', 'W96'],
  101: ['W97', 'W98'], 102: ['W99', 'W100'], 103: ['L101', 'L102'], 104: ['W101', 'W102'],
};

export interface BracketColumn { round: string; nums: number[] }
/** Column layout — match numbers in vertical order so adjacent pairs feed the next round. */
export const WC_BRACKET: {
  left: BracketColumn[];
  right: BracketColumn[];
  final: number;
  bronze: number;
} = {
  left: [
    { round: 'Round of 32', nums: [74, 77, 73, 75, 83, 84, 81, 82] },
    { round: 'Round of 16', nums: [89, 90, 93, 94] },
    { round: 'Quarter-finals', nums: [97, 98] },
    { round: 'Semi-finals', nums: [101] },
  ],
  right: [
    { round: 'Semi-finals', nums: [102] },
    { round: 'Quarter-finals', nums: [99, 100] },
    { round: 'Round of 16', nums: [91, 92, 95, 96] },
    { round: 'Round of 32', nums: [76, 78, 79, 80, 86, 88, 85, 87] },
  ],
  final: 104,
  bronze: 103,
};

const NATION_ALIASES: Record<string, string> = {
  unitedstates: 'usa', usa: 'usa',
  drcongo: 'congodr', congodr: 'congodr',
  capeverde: 'capeverde', capeverdeislands: 'capeverde', caboverde: 'capeverde',
  bosniaandherzegovina: 'bosnia', bosniaherzegovina: 'bosnia',
  korearepublic: 'southkorea', southkorea: 'southkorea',
  czechrepublic: 'czechia', czechia: 'czechia',
  turkey: 'turkiye', turkiye: 'turkiye',
};

/** Normalise a nation name so template/feed names and api names compare equal. */
export function normNation(name: string): string {
  const n = name
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z]/g, '');
  return NATION_ALIASES[n] ?? n;
}

/** A URL-safe match slug: "canada-vs-bosnia-and-herzegovina-2026-06-13". */
export function matchSlug(home: string, away: string, kickoffISO: string): string {
  const norm = (s: string) =>
    s.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '')
      .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
  const date = kickoffISO.slice(0, 10);
  return `${norm(home)}-vs-${norm(away)}-${date}`;
}
