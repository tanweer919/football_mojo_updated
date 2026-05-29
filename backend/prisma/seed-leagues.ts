/**
 * Multi-league seed. Walks every entry in `LEAGUES` (see
 * `src/modules/competitions/leagues.config.ts`) and ensures we have:
 *   - Competition row
 *   - All teams (with crests, country code)
 *   - Every fixture for the configured season
 *   - PlayerValuation seeds for every squad player (only when the league's
 *     `seedSquads = true`; squad walks are 20+ extra calls per league)
 *
 * Idempotent. Re-run any time. Honors `SEED_REQUEST_DELAY_MS` to stay under
 * api-football's per-minute rate limit on the free tier.
 *
 * Run: `npm run seed:leagues`
 *
 * Optional env to scope:
 *   SEED_LEAGUE_IDS=1,39           — only WC + Premier League
 *   SEED_REQUEST_DELAY_MS=0        — paid tier, no throttle
 */

import { PlayerPosition, PrismaClient } from '@prisma/client';
import axios, { AxiosError } from 'axios';
import 'dotenv/config';

const prisma = new PrismaClient();

// ─────────────────────────────────────────────────────────────────────────────
// Inlined from `src/modules/competitions/leagues.config.ts`. The runtime
// Docker image ships dist/ and prisma/ — not src/ — so this script can't
// import from the source tree. KEEP IN SYNC: when you add or remove a
// league here, mirror the change in the canonical config or the poller and
// seed will diverge.
// ─────────────────────────────────────────────────────────────────────────────
interface LeagueConfig {
  id: number;
  season: number;
  code: string;
  name: string;
  type: 'tournament' | 'league';
  country?: string;
  seedSquads: boolean;
  startsAt: string;
  endsAt: string;
}

const LEAGUES: LeagueConfig[] = [
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
  {
    id: 39, season: 2025, code: 'PL_2025',
    name: 'Premier League', type: 'league', country: 'ENG',
    seedSquads: false,
    startsAt: '2025-08-15T00:00:00Z',
    endsAt:   '2026-05-25T23:59:59Z',
  },
  {
    id: 140, season: 2025, code: 'LALIGA_2025',
    name: 'La Liga', type: 'league', country: 'ESP',
    seedSquads: false,
    startsAt: '2025-08-15T00:00:00Z',
    endsAt:   '2026-05-25T23:59:59Z',
  },
  {
    id: 135, season: 2025, code: 'SERIEA_2025',
    name: 'Serie A', type: 'league', country: 'ITA',
    seedSquads: false,
    startsAt: '2025-08-22T00:00:00Z',
    endsAt:   '2026-05-25T23:59:59Z',
  },
  {
    id: 78, season: 2025, code: 'BUNDES_2025',
    name: 'Bundesliga', type: 'league', country: 'GER',
    seedSquads: false,
    startsAt: '2025-08-22T00:00:00Z',
    endsAt:   '2026-05-23T23:59:59Z',
  },
  {
    id: 61, season: 2025, code: 'LIGUE1_2025',
    name: 'Ligue 1', type: 'league', country: 'FRA',
    seedSquads: false,
    startsAt: '2025-08-15T00:00:00Z',
    endsAt:   '2026-05-23T23:59:59Z',
  },
];

function activeLeagueIds(envCsv?: string): LeagueConfig[] {
  if (!envCsv?.trim()) return LEAGUES;
  const allowed = new Set(envCsv.split(',').map((s) => Number(s.trim())).filter(Number.isFinite));
  return LEAGUES.filter((l) => allowed.has(l.id));
}

// NOTE: kept inline (not imported from src/) because the prod runtime
// image only ships dist/ + prisma/. Keep this in sync with the canonical
// version in src/modules/api-football/api-football.config.ts.
//
// `||` (not `??`) is deliberate — empty-string env vars from docker-
// compose's `KEY=` syntax must fall through to the default. The earlier
// `??`-based version produced baseURL: '' and crashed every request
// with "Invalid URL".
const RAPIDAPI_HOST = 'api-football-v1.p.rapidapi.com';
function resolveApiFootballConfig() {
  const key = process.env.API_FOOTBALL_KEY?.trim();
  if (!key) throw new Error('API_FOOTBALL_KEY is required');
  const provider = (process.env.API_FOOTBALL_PROVIDER ?? 'direct').trim().toLowerCase();
  const baseOverride = process.env.API_FOOTBALL_BASE?.trim() || undefined;
  if (provider === 'rapidapi') {
    return {
      baseURL: baseOverride ?? `https://${RAPIDAPI_HOST}/v3`,
      headers: { 'x-rapidapi-host': RAPIDAPI_HOST, 'x-rapidapi-key': key },
    };
  }
  return {
    baseURL: baseOverride ?? 'https://v3.football.api-sports.io',
    headers: { 'x-apisports-key': key },
  };
}

function mapApiFootballStatus(short: string): 'SCHEDULED' | 'LIVE' | 'HALF_TIME' | 'FINISHED' | 'POSTPONED' | 'CANCELLED' {
  switch (short) {
    case 'NS': case 'TBD':                                       return 'SCHEDULED';
    case '1H': case '2H': case 'LIVE': case 'ET': case 'P':
    case 'BT': case 'SUSP': case 'INT':                          return 'LIVE';
    case 'HT':                                                   return 'HALF_TIME';
    case 'FT': case 'AET': case 'PEN':                           return 'FINISHED';
    case 'PST':                                                  return 'POSTPONED';
    case 'CANC': case 'ABD': case 'AWD': case 'WO':              return 'CANCELLED';
    default: return 'SCHEDULED';
  }
}

const REQUEST_DELAY_MS = Number(process.env.SEED_REQUEST_DELAY_MS ?? '250');
const MAX_RETRIES = 5;
const api = axios.create({ ...resolveApiFootballConfig(), timeout: 30_000 });
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function fetchUpstream<T>(path: string, params: Record<string, string | number>): Promise<T[]> {
  let lastErr: unknown;
  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    try {
      if (attempt > 0) {
        const backoff = Math.min(60_000, 1_000 * 2 ** (attempt - 1));
        console.warn(`  retry ${attempt}/${MAX_RETRIES} for ${path} after ${backoff}ms`);
        await sleep(backoff);
      }
      const res = await api.get(path, { params });
      const data = res.data;
      if (typeof data?.message === 'string' && !Array.isArray(data?.response)) {
        throw new Error(`api-football (rapidapi) error: ${data.message}`);
      }
      const hasErrors = Array.isArray(data.errors)
        ? data.errors.length > 0
        : data.errors && Object.keys(data.errors).length > 0;
      if (hasErrors) throw new Error(`api-football errors: ${JSON.stringify(data.errors)}`);

      const perMin = res.headers['x-ratelimit-remaining'];
      const daily  = res.headers['x-ratelimit-requests-remaining'];
      if (perMin || daily) {
        process.stdout.write(`  ✓ ${path}  (${perMin ?? '?'}/min · ${daily ?? '?'}/day)        \r`);
      }
      if (REQUEST_DELAY_MS) await sleep(REQUEST_DELAY_MS);
      return (data.response ?? []) as T[];
    } catch (err) {
      lastErr = err;
      const isAxios = axios.isAxiosError(err);
      const status = isAxios ? (err as AxiosError).response?.status : 0;
      const retryable = !status || status === 429 || (status >= 500 && status < 600);
      if (!retryable) break;
      if (status === 429 && isAxios) {
        const ra = (err as AxiosError).response?.headers?.['retry-after'];
        const sec = ra ? Number(ra) : 0;
        if (sec > 0) {
          console.warn(`  429 — retry after ${sec}s`);
          await sleep(sec * 1_000);
        }
      }
    }
  }
  throw lastErr instanceof Error ? lastErr : new Error(String(lastErr));
}

function mapPosition(label: string): PlayerPosition {
  const l = label.toLowerCase();
  if (l.startsWith('goal')) return 'GK';
  if (l.startsWith('def'))  return 'DEF';
  if (l.startsWith('att') || l.startsWith('forward')) return 'FWD';
  return 'MID';
}

function defaultPriceFor(position: PlayerPosition): number {
  switch (position) {
    case 'GK':  return 5.0;
    case 'DEF': return 5.5;
    case 'MID': return 6.5;
    case 'FWD': return 7.5;
  }
}

const COUNTRY_2LETTER: Record<string, string> = {
  ARG: 'ar', BRA: 'br', FRA: 'fr', ENG: 'gb-eng', ESP: 'es', GER: 'de',
  POR: 'pt', NED: 'nl', ITA: 'it', BEL: 'be', CRO: 'hr', MEX: 'mx',
  USA: 'us', CAN: 'ca', MAR: 'ma', JPN: 'jp', URU: 'uy', SEN: 'sn',
  NOR: 'no', EGY: 'eg', SUI: 'ch', POL: 'pl', SCO: 'gb-sct', WAL: 'gb-wls',
  IRL: 'ie', DEN: 'dk', SWE: 'se', RUS: 'ru', UKR: 'ua', TUR: 'tr',
  AUS: 'au', NZL: 'nz', JOR: 'jo', IRN: 'ir', KOR: 'kr', QAT: 'qa',
  KSA: 'sa', UAE: 'ae', GHA: 'gh', NGA: 'ng', SRB: 'rs', AUT: 'at',
  COL: 'co', CHI: 'cl', PER: 'pe', PAR: 'py', VEN: 've', ECU: 'ec',
  CRC: 'cr', PAN: 'pa', HON: 'hn', JAM: 'jm',
};
function isoFlagCode(teamCode: string | null): string | null {
  if (!teamCode) return null;
  const upper = teamCode.toUpperCase();
  return COUNTRY_2LETTER[upper] ?? upper.toLowerCase();
}

interface ApiTeam {
  team: { id: number; name: string; code: string | null; country: string; logo: string };
}
interface ApiSquadResponse {
  team: { id: number };
  players: Array<{
    id: number;
    name: string;
    age: number | null;
    number: number | null;
    position: string;
    photo: string;
  }>;
}
interface ApiFixturePayload {
  fixture: { id: number; date: string; venue: { name: string | null }; status: { short: string; elapsed: number | null } };
  league:  { id: number; round: string };
  teams:   { home: { id: number; name: string; logo: string }; away: { id: number; name: string; logo: string } };
  goals:   { home: number | null; away: number | null };
  score:   { penalty: { home: number | null; away: number | null } };
}

async function ensureCompetition(l: LeagueConfig) {
  await prisma.competition.upsert({
    where: { id: l.code },
    create: {
      id: l.code,
      name: l.name,
      type: l.type,
      season: String(l.season),
      startsAt: new Date(l.startsAt),
      endsAt: new Date(l.endsAt),
      emblemUrl: `https://media.api-sports.io/football/leagues/${l.id}.png`,
    },
    update: {
      name: l.name,
      type: l.type,
      season: String(l.season),
      startsAt: new Date(l.startsAt),
      endsAt: new Date(l.endsAt),
      emblemUrl: `https://media.api-sports.io/football/leagues/${l.id}.png`,
    },
  });
}

async function seedTeams(l: LeagueConfig) {
  console.log(`\n▸ ${l.name} — teams`);
  const teams = await fetchUpstream<ApiTeam>('/teams', { league: l.id, season: l.season });
  console.log(`  ${teams.length} teams`);
  for (const t of teams) {
    const flagCode = isoFlagCode(t.team.code);
    await prisma.team.upsert({
      where: { id: String(t.team.id) },
      create: {
        id: String(t.team.id),
        competitionId: l.code,
        name: t.team.name,
        shortName: t.team.code ?? t.team.name.slice(0, 3).toUpperCase(),
        countryCode: flagCode,
        crestUrl: t.team.logo,
      },
      update: {
        // Don't blindly overwrite competitionId — a club team may also play
        // in a tournament we track. First-write wins.
        name: t.team.name,
        shortName: t.team.code ?? t.team.name.slice(0, 3).toUpperCase(),
        countryCode: flagCode,
        crestUrl: t.team.logo,
      },
    });
  }
  return teams;
}

async function seedSquads(l: LeagueConfig, teams: ApiTeam[]) {
  console.log(`\n▸ ${l.name} — squads`);
  for (const t of teams) {
    console.log(`  squad: ${t.team.name}`);
    const squads = await fetchUpstream<ApiSquadResponse>('/players/squads', { team: t.team.id });
    const players = squads[0]?.players ?? [];
    for (const p of players) {
      const pos = mapPosition(p.position);
      await prisma.player.upsert({
        where: { id: String(p.id) },
        create: {
          id: String(p.id),
          teamId: String(t.team.id),
          name: p.name,
          shirtNumber: p.number,
          position: pos,
          nationality: t.team.country,
          photoUrl: p.photo,
        },
        update: {
          teamId: String(t.team.id),
          name: p.name,
          shirtNumber: p.number,
          position: pos,
          nationality: t.team.country,
          photoUrl: p.photo,
        },
      });
      await prisma.playerValuation.upsert({
        where: { playerId: String(p.id) },
        create: { playerId: String(p.id), price: defaultPriceFor(pos), recentForm: 0, position: pos },
        update: { position: pos },
      });
    }
  }
}

async function seedFixtures(l: LeagueConfig) {
  console.log(`\n▸ ${l.name} — fixtures`);
  const fixtures = await fetchUpstream<ApiFixturePayload>('/fixtures', { league: l.id, season: l.season });
  console.log(`  ${fixtures.length} fixtures`);
  for (const f of fixtures) {
    if (!f.teams?.home?.id || !f.teams?.away?.id) continue;
    // Make sure the team rows exist (some fixtures reference teams that
    // weren't returned by /teams — older relegated sides, e.g.).
    await prisma.team.upsert({
      where: { id: String(f.teams.home.id) },
      create: { id: String(f.teams.home.id), competitionId: l.code, name: f.teams.home.name, shortName: f.teams.home.name.slice(0, 3).toUpperCase(), crestUrl: f.teams.home.logo },
      update: { crestUrl: f.teams.home.logo },
    });
    await prisma.team.upsert({
      where: { id: String(f.teams.away.id) },
      create: { id: String(f.teams.away.id), competitionId: l.code, name: f.teams.away.name, shortName: f.teams.away.name.slice(0, 3).toUpperCase(), crestUrl: f.teams.away.logo },
      update: { crestUrl: f.teams.away.logo },
    });
    await prisma.match.upsert({
      where: { id: String(f.fixture.id) },
      create: {
        id: String(f.fixture.id),
        competitionId: l.code,
        homeTeamId: String(f.teams.home.id),
        awayTeamId: String(f.teams.away.id),
        kickoffAt: new Date(f.fixture.date),
        status: mapApiFootballStatus(f.fixture.status.short),
        minute: f.fixture.status.elapsed,
        homeScore: f.goals.home ?? 0,
        awayScore: f.goals.away ?? 0,
        homePenalties: f.score.penalty.home,
        awayPenalties: f.score.penalty.away,
        stage: f.league.round,
        venue: f.fixture.venue.name,
      },
      update: {
        status: mapApiFootballStatus(f.fixture.status.short),
        minute: f.fixture.status.elapsed,
        homeScore: f.goals.home ?? 0,
        awayScore: f.goals.away ?? 0,
        stage: f.league.round,
      },
    });
  }
}

async function run() {
  const targets = activeLeagueIds(process.env.SEED_LEAGUE_IDS);
  console.log(`Seeding ${targets.length} league(s): ${targets.map((l) => l.code).join(', ')}`);
  let teamsTotal = 0;
  let fixturesTotal = 0;
  for (const l of targets) {
    await ensureCompetition(l);
    const teams = await seedTeams(l);
    teamsTotal += teams.length;
    if (l.seedSquads) await seedSquads(l, teams);
    await seedFixtures(l);
    const fxCount = await prisma.match.count({ where: { competitionId: l.code } });
    fixturesTotal += fxCount;
  }
  console.log(`\n✓ done — ${targets.length} leagues · ${teamsTotal} teams · ${fixturesTotal} fixtures`);
}

run()
  .catch((err) => {
    console.error('seed-leagues failed:', err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
