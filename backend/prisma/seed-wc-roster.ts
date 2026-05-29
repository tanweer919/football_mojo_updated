/**
 * Focused refresh of the WC roster only — teams + squads + photos.
 *
 * Scope (smaller and faster than the full `seed.ts`):
 *   - 48 WC teams (logos + countryCode + name)
 *   - Each team's squad (player ids, names, shirt numbers, positions, photos)
 *   - PlayerValuation entries with default prices for any new player
 *
 * Idempotent. Skips fixtures, fantasy gameweeks, card templates, and prizes.
 *
 * Use when:
 *   - A national-team coach announces a final squad late
 *   - api-football updates a player's photo or shirt number
 *   - You want to reset just the rosters without re-running the full seed
 *
 * Run: `npm run seed:roster`
 */

import { PrismaClient, PlayerPosition } from '@prisma/client';
import axios, { AxiosError } from 'axios';
import 'dotenv/config';

const prisma = new PrismaClient();

const RAPIDAPI_HOST = 'api-football-v1.p.rapidapi.com';
// NOTE: kept inline (not imported from src/) because the prod runtime
// image only ships dist/ + prisma/. Keep this in sync with the canonical
// version in src/modules/api-football/api-football.config.ts.
//
// `||` (not `??`) is deliberate — empty-string env vars from docker-
// compose's `KEY=` syntax must fall through to the default. The earlier
// `??`-based version produced baseURL: '' on prod and crashed every
// request with "Invalid URL".
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

const LEAGUE = Number(process.env.API_FOOTBALL_WC_LEAGUE_ID ?? '1');
const SEASON = Number(process.env.API_FOOTBALL_WC_SEASON   ?? '2026');
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
          console.warn(`  429 — server says retry after ${sec}s`);
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

/**
 * Country code normalization. api-football's team `code` for national teams is
 * a 3-letter abbreviation (ARG, BRA, FRA). For 2-letter ISO flag URLs we map
 * a few known ones; the rest fall back to lowercased team code, which is
 * usually accepted by the flag endpoint.
 */
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

function isoFlagCode(teamCode: string | null, countryName: string | null): string | null {
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

async function refreshTeamsAndSquads() {
  console.log(`▸ Pulling WC ${SEASON} teams (league=${LEAGUE})…`);
  const teams = await fetchUpstream<ApiTeam>('/teams', { league: LEAGUE, season: SEASON });
  console.log(`  ${teams.length} teams returned`);

  // Ensure the parent competition exists (idempotent, doesn't replace anything).
  await prisma.competition.upsert({
    where: { id: 'WC2026' },
    create: {
      id: 'WC2026',
      name: 'FIFA World Cup 2026',
      type: 'tournament',
      season: String(SEASON),
      startsAt: new Date(`${SEASON}-06-11T00:00:00Z`),
      endsAt:   new Date(`${SEASON}-07-19T23:59:59Z`),
      emblemUrl: null,
    },
    update: {},
  });

  let teamsUpserted = 0;
  let playersUpserted = 0;
  let valuationsUpserted = 0;

  for (const t of teams) {
    const teamId = String(t.team.id);
    const flagCode = isoFlagCode(t.team.code, t.team.country);

    await prisma.team.upsert({
      where: { id: teamId },
      create: {
        id: teamId,
        competitionId: 'WC2026',
        name: t.team.name,
        shortName: t.team.code ?? t.team.name.slice(0, 3).toUpperCase(),
        countryCode: flagCode,
        crestUrl: t.team.logo,
      },
      update: {
        competitionId: 'WC2026',
        name: t.team.name,
        shortName: t.team.code ?? t.team.name.slice(0, 3).toUpperCase(),
        countryCode: flagCode,
        crestUrl: t.team.logo,
      },
    });
    teamsUpserted++;

    console.log(`  squad: ${t.team.name} (${flagCode ?? '??'})`);
    const squads = await fetchUpstream<ApiSquadResponse>('/players/squads', { team: t.team.id });
    const players = squads[0]?.players ?? [];

    for (const p of players) {
      const pos = mapPosition(p.position);
      await prisma.player.upsert({
        where: { id: String(p.id) },
        create: {
          id: String(p.id),
          teamId,
          name: p.name,
          shirtNumber: p.number,
          position: pos,
          nationality: t.team.country,
          photoUrl: p.photo,
        },
        update: {
          teamId,
          name: p.name,
          shirtNumber: p.number,
          position: pos,
          nationality: t.team.country,
          photoUrl: p.photo,
        },
      });
      playersUpserted++;

      await prisma.playerValuation.upsert({
        where: { playerId: String(p.id) },
        create: { playerId: String(p.id), price: defaultPriceFor(pos), recentForm: 0, position: pos },
        update: { position: pos },
      });
      valuationsUpserted++;
    }
  }

  console.log('');
  console.log(`✓ done — ${teamsUpserted} teams · ${playersUpserted} players · ${valuationsUpserted} valuations`);
}

refreshTeamsAndSquads()
  .catch((err) => {
    console.error('roster seed failed:', err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
