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
    id: 2, season: 2026, code: 'UCL_2025',
    name: 'UEFA Champions League', type: 'tournament', country: 'EUR',
    seedSquads: false,
    startsAt: '2025-09-01T00:00:00Z',
    endsAt:   '2026-06-01T23:59:59Z',
  },
  {
    id: 3, season: 2026, code: 'UEL_2025',
    name: 'UEFA Europa League', type: 'tournament', country: 'EUR',
    seedSquads: false,
    startsAt: '2025-09-01T00:00:00Z',
    endsAt:   '2026-05-30T23:59:59Z',
  },

  // Domestic top flights — fixtures + teams only by default; squads are huge
  // (~25/team × 20 teams = 500 players × 5 leagues = 2.5k api calls).
  {
    id: 39, season: 2026, code: 'PL_2025',
    name: 'Premier League', type: 'league', country: 'ENG',
    seedSquads: false,
    startsAt: '2025-08-15T00:00:00Z',
    endsAt:   '2026-05-25T23:59:59Z',
  },
  {
    id: 140, season: 2026, code: 'LALIGA_2025',
    name: 'La Liga', type: 'league', country: 'ESP',
    seedSquads: false,
    startsAt: '2025-08-15T00:00:00Z',
    endsAt:   '2026-05-25T23:59:59Z',
  },
  {
    id: 135, season: 2026, code: 'SERIEA_2025',
    name: 'Serie A', type: 'league', country: 'ITA',
    seedSquads: false,
    startsAt: '2025-08-22T00:00:00Z',
    endsAt:   '2026-05-25T23:59:59Z',
  },
  {
    id: 78, season: 2026, code: 'BUNDES_2025',
    name: 'Bundesliga', type: 'league', country: 'GER',
    seedSquads: false,
    startsAt: '2025-08-22T00:00:00Z',
    endsAt:   '2026-05-23T23:59:59Z',
  },
  {
    id: 61, season: 2026, code: 'LIGUE1_2025',
    name: 'Ligue 1', type: 'league', country: 'FRA',
    seedSquads: false,
    startsAt: '2025-08-15T00:00:00Z',
    endsAt:   '2026-05-23T23:59:59Z',
  },
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
