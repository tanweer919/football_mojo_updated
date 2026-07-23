/**
 * Single source of truth for which competitions PITCH ingests.
 *
 * Order matters in two places:
 *   - the seed walks this list top → bottom
 *   - the poller's idle scan respects the order so the WC always wins ties
 *
 * To add a league post-launch:
 *   1. Append a row here
 *   2. Run `npm run seed:leagues` (or restart the worker — the poller will
 *      eventually pick up new fixtures via the live tick)
 *   3. No app update needed; the Flutter client renders whatever the API serves.
 *
 * Each row's `id` is the api-football league id (see /v3/leagues).
 * `season` is api-football's "season starting year" — Premier League 2025/26
 * lives under season=2025; the WC 2026 (single-year) lives under season=2026.
 */
export interface LeagueConfig {
  /** api-football league id */
  id: number;
  /** api-football season (year the season starts) */
  season: number;
  /** Stable internal id used as Competition.id (Prisma PK) */
  code: string;
  name: string;
  type: 'tournament' | 'league';
  /** Optional friendly country code (3-letter or 2-letter). Cosmetic. */
  country?: string;
  /** When true, the seed walks every team's squad. Free-tier expensive — keep
   *  this on for the WC and OFF for the big-five leagues. */
  seedSquads: boolean;
  /** Reasonable season window (used for `Competition.startsAt/endsAt` defaults). */
  startsAt: string; // ISO
  endsAt: string;   // ISO
}

// Domestic top flights. api-football serves several completed seasons, so we
// surface the last few — that's what powers the app's league YEAR selector.
// It's the football off-season (WC just ended; new seasons start in August),
// so the newest COMPLETED season (2025/26 → api season 2025) is the default and
// has full data. Add 2026 here once the 2026/27 season actually kicks off.
const DOMESTIC = [
  { id: 39,  base: 'PL',     name: 'Premier League', country: 'ENG', start: '08-15', end: '05-25' },
  { id: 140, base: 'LALIGA', name: 'La Liga',        country: 'ESP', start: '08-15', end: '05-25' },
  { id: 135, base: 'SERIEA', name: 'Serie A',        country: 'ITA', start: '08-22', end: '05-25' },
  { id: 78,  base: 'BUNDES', name: 'Bundesliga',     country: 'GER', start: '08-22', end: '05-23' },
  { id: 61,  base: 'LIGUE1', name: 'Ligue 1',        country: 'FRA', start: '08-15', end: '05-23' },
] as const;
const CLUB_SEASONS = [2025, 2024, 2023]; // completed seasons with data, newest first

const domesticLeagues: LeagueConfig[] = DOMESTIC.flatMap((d) =>
  CLUB_SEASONS.map((season): LeagueConfig => ({
    id: d.id,
    season,
    code: `${d.base}_${season}`,
    name: d.name,
    type: 'league',
    country: d.country,
    seedSquads: false,
    startsAt: `${season}-${d.start}T00:00:00Z`,
    endsAt: `${season + 1}-${d.end}T23:59:59Z`,
  })),
);

export const LEAGUES: LeagueConfig[] = [
  // International tournaments — full squad ingest, treated as the headline competition.
  {
    id: 1, season: 2026, code: 'WC2026',
    name: 'FIFA World Cup 2026', type: 'tournament', country: 'WORLD',
    seedSquads: true,
    startsAt: '2026-06-11T00:00:00Z',
    endsAt:   '2026-07-19T23:59:59Z',
  },
  {
    id: 2, season: 2025, code: 'UCL_2025',
    name: 'UEFA Champions League', type: 'tournament', country: 'EUR',
    seedSquads: false,
    startsAt: '2025-09-01T00:00:00Z',
    endsAt:   '2026-06-01T23:59:59Z',
  },
  {
    id: 3, season: 2025, code: 'UEL_2025',
    name: 'UEFA Europa League', type: 'tournament', country: 'EUR',
    seedSquads: false,
    startsAt: '2025-09-01T00:00:00Z',
    endsAt:   '2026-05-30T23:59:59Z',
  },

  // Domestic top flights (last few completed seasons — see DOMESTIC/CLUB_SEASONS
  // above). Fixtures + teams only; squads are huge on the free tier.
  ...domesticLeagues,
];

/** Lookup by api-football league id. Returns undefined for leagues we don't track. */
export function findLeagueByApiId(id: number): LeagueConfig | undefined {
  return LEAGUES.find((l) => l.id === id);
}

/** Convert "Premier League · 2025" into our internal `Competition.id`. */
export function competitionIdForApi(leagueId: number): string | null {
  return findLeagueByApiId(leagueId)?.code ?? null;
}

/** Comma-separated env override (`POLL_LEAGUE_IDS=1,39,140`) for one-off scoping. */
export function activeLeagueIds(envCsv?: string): LeagueConfig[] {
  if (!envCsv?.trim()) return LEAGUES;
  const allowed = new Set(envCsv.split(',').map((s) => Number(s.trim())).filter(Number.isFinite));
  return LEAGUES.filter((l) => allowed.has(l.id));
}
