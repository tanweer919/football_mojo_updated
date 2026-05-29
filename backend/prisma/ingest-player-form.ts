/**
 * Pull per-player season aggregates from api-football and write them onto
 * PlayerValuation.{seasonRating, seasonGoals, seasonAssists, …}. The
 * fantasy repricer then uses `seasonRating` as the form-boost baseline so
 * top performers price out at the top of the budget even when our own
 * PlayerGameweekScore table is empty (i.e. pre-WC).
 *
 * api-football endpoint:
 *   GET /v3/players?league={id}&season={year}&page={N}
 *
 * Each row in the `response[]` array carries:
 *   - player.{id, name, photo}
 *   - statistics[] — usually one row per (player, team) pair within that
 *     league+season, with `games.{appearences, minutes, position, rating}`,
 *     `goals.{total, assists}`, etc.
 *
 * Strategy: walk every configured league + season pair, paginate, and for
 * every player we know about (Player row exists in our DB) compute a
 * blended rating across all statistics rows (handles loans / mid-season
 * transfers) and upsert it onto their PlayerValuation.
 *
 * Run:
 *   npm run ingest:form
 *   API_FOOTBALL_KEY=... LEAGUES=39,140,135 SEASON=2024 npm run ingest:form
 */

import { PrismaClient, PlayerPosition } from '@prisma/client';
import axios, { AxiosError } from 'axios';
import 'dotenv/config';

const prisma = new PrismaClient();

/**
 * When true the script also UPSERTS missing Team + Player + PlayerValuation
 * rows before writing the rating. Set `IMPORT_MISSING=1 npm run ingest:form`
 * to bring every Big-5 + UCL/UEL player into our DB. Default is off — a
 * pure "update existing valuations" pass — so accidental runs don't
 * balloon the player table.
 */
const IMPORT_MISSING = process.env.IMPORT_MISSING === '1';

/// api-football's league id → our Competition.code. Drives Team.competitionId
/// when we upsert teams during IMPORT_MISSING. Kept in lock-step with
/// `src/modules/competitions/leagues.config.ts`.
const LEAGUE_TO_COMPETITION: Record<number, string> = {
  39:  'PL_2025',
  140: 'LALIGA_2025',
  78:  'BUNDESLIGA_2025',
  135: 'SERIEA_2025',
  61:  'LIGUE1_2025',
  2:   'UCL_2025',
  3:   'UEL_2025',
};

/// api-football labels position as "Goalkeeper" / "Defender" / "Midfielder"
/// / "Attacker". Same mapping as `prisma/seed-wc-roster.ts` — kept inline
/// so this script stays standalone (Docker container doesn't ship src/).
function mapPosition(label: string | null | undefined): PlayerPosition {
  if (!label) return 'MID';
  const l = label.toLowerCase();
  if (l.startsWith('goal')) return 'GK';
  if (l.startsWith('def'))  return 'DEF';
  if (l.startsWith('att') || l.startsWith('forward')) return 'FWD';
  return 'MID';
}

/// Same floor table as PRICING.floorByPosition — duplicated here to keep
/// the script self-contained. Repricer will overwrite immediately anyway.
function defaultPriceFor(position: PlayerPosition): number {
  return position === 'GK' ? 10 : position === 'DEF' ? 11 : position === 'MID' ? 12 : 13;
}

// NOTE: kept inline (not imported from src/) because the prod runtime
// image only ships dist/ + prisma/. Keep this in sync with the canonical
// version in src/modules/api-football/api-football.config.ts.
//
// `||` (not `??`) deliberate so empty-string env vars fall through.
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

const api = axios.create({ ...resolveApiFootballConfig(), timeout: 30_000 });
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

const REQUEST_DELAY_MS = Number(process.env.INGEST_REQUEST_DELAY_MS ?? '600');
const MAX_RETRIES = 5;

// Defaults: the Big Five + UCL/UEL, sampled from the last completed
// season. Override at runtime with LEAGUES=39,140 SEASON=2024.
interface LeagueSample { id: number; season: number; label: string; }
const DEFAULT_SAMPLE: LeagueSample[] = [
  { id: 39,  season: 2024, label: 'Premier League' },
  { id: 140, season: 2024, label: 'La Liga' },
  { id: 78,  season: 2024, label: 'Bundesliga' },
  { id: 135, season: 2024, label: 'Serie A' },
  { id: 61,  season: 2024, label: 'Ligue 1' },
  { id: 2,   season: 2024, label: 'UEFA Champions League' },
  { id: 3,   season: 2024, label: 'UEFA Europa League' },
];

function sampleFromEnv(): LeagueSample[] {
  const csv = process.env.LEAGUES?.trim();
  const season = Number(process.env.SEASON ?? '2024');
  if (!csv) return DEFAULT_SAMPLE;
  return csv.split(',').map((id) => ({
    id: Number(id.trim()),
    season,
    label: `League ${id.trim()}`,
  }));
}

interface ApiPlayerResp {
  response: Array<{
    player: { id: number; name: string; photo?: string; nationality?: string };
    statistics: Array<{
      team?: { id?: number; name?: string; logo?: string };
      league?: { id?: number; season?: number };
      games?: {
        appearences?: number;
        minutes?: number;
        rating?: string | number | null;
        position?: string;
      };
      goals?: { total?: number | null; assists?: number | null };
    }>;
  }>;
  paging?: { current: number; total: number };
}

async function fetchPage(leagueId: number, season: number, page: number): Promise<ApiPlayerResp> {
  let lastErr: unknown;
  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    try {
      if (attempt > 0) {
        const backoff = Math.min(60_000, 1_000 * 2 ** (attempt - 1));
        console.warn(`  retry ${attempt}/${MAX_RETRIES} after ${backoff}ms`);
        await sleep(backoff);
      }
      const res = await api.get('/players', {
        params: { league: leagueId, season, page },
      });
      return res.data as ApiPlayerResp;
    } catch (e) {
      lastErr = e;
      const status = (e as AxiosError).response?.status;
      if (status && status !== 429 && status < 500) throw e;
    }
  }
  throw lastErr;
}

interface PlayerAgg {
  ratingSum: number;
  ratingN: number;
  appearances: number;
  minutes: number;
  goals: number;
  assists: number;
  // Carried through so IMPORT_MISSING can upsert Team + Player rows when
  // the player isn't already in our DB.
  meta: {
    name: string;
    photo?: string;
    nationality?: string;
    // Pick the team they played most for in this window — defined as the
    // first statistics[] entry (api-football orders by competition primacy).
    teamId?: string;
    teamName?: string;
    teamLogo?: string;
    leagueId?: number;
    position?: string;
  };
}

async function main() {
  const samples = sampleFromEnv();
  console.log(`[ingest-form] leagues=${samples.map((s) => s.id).join(',')} season=${samples[0]?.season}`);

  // Build a single map keyed by api-football player id (which is also
  // our Player.id — the seed scripts use upstream ids verbatim).
  const agg = new Map<string, PlayerAgg>();

  for (const sample of samples) {
    let page = 1;
    let totalPages = 1;
    while (page <= totalPages) {
      console.log(`[${sample.label}] page ${page}/${totalPages}`);
      const data = await fetchPage(sample.id, sample.season, page);
      totalPages = data.paging?.total ?? 1;
      page++;

      for (const row of data.response ?? []) {
        const id = `${row.player.id}`;
        const firstStat = row.statistics?.[0];
        // Blend across all statistics rows for this player in this
        // league+season (covers mid-season transfers, multiple comps).
        let r = agg.get(id);
        if (!r) {
          r = {
            ratingSum: 0, ratingN: 0, appearances: 0, minutes: 0, goals: 0, assists: 0,
            meta: {
              name: row.player.name,
              photo: row.player.photo,
              nationality: row.player.nationality,
              teamId: firstStat?.team?.id == null ? undefined : `${firstStat.team.id}`,
              teamName: firstStat?.team?.name,
              teamLogo: firstStat?.team?.logo,
              leagueId: sample.id,
              position: firstStat?.games?.position,
            },
          };
          agg.set(id, r);
        }
        for (const s of row.statistics ?? []) {
          const rating = s.games?.rating == null ? null : Number(s.games.rating);
          if (rating != null && !Number.isNaN(rating)) {
            r.ratingSum += rating;
            r.ratingN++;
          }
          r.appearances += s.games?.appearences ?? 0;
          r.minutes += s.games?.minutes ?? 0;
          r.goals += s.goals?.total ?? 0;
          r.assists += s.goals?.assists ?? 0;
        }
      }
      await sleep(REQUEST_DELAY_MS);
    }
  }

  console.log(`[ingest-form] aggregated ${agg.size} players across all leagues. mode=${IMPORT_MISSING ? 'IMPORT_MISSING' : 'UPDATE_ONLY'}`);

  // Cache existing valuation ids + existing team ids so we don't hit
  // findUnique for every one of the 7k rows.
  const valuations = await prisma.playerValuation.findMany({
    select: { id: true, playerId: true },
  });
  const valByPlayerId = new Map(valuations.map((v) => [v.playerId, v.id]));
  const teams = await prisma.team.findMany({ select: { id: true } });
  const knownTeamIds = new Set(teams.map((t) => t.id));

  const seasonSampled = samples[0]?.season ?? 2024;
  let updated = 0;
  let createdPlayers = 0;
  let createdTeams = 0;
  let skipped = 0;
  let teamUnknown = 0;

  for (const [playerId, r] of agg) {
    const avgRating = r.ratingN > 0 ? r.ratingSum / r.ratingN : null;
    let valuationId = valByPlayerId.get(playerId);

    if (!valuationId) {
      // Player isn't in our DB. Without IMPORT_MISSING we leave them out —
      // the original "skipped" path. With it, upsert Team → Player →
      // PlayerValuation so the next pass + the repricer can use them.
      if (!IMPORT_MISSING) {
        skipped++;
        continue;
      }
      const teamId = r.meta.teamId;
      if (!teamId) {
        teamUnknown++;
        continue;
      }
      // 1. Upsert the team if needed. We require a competition mapping —
      //    if api-football's league id isn't in LEAGUE_TO_COMPETITION,
      //    we still create the team but leave competitionId null (it
      //    won't show in our league lists but the player still works
      //    for ratings).
      if (!knownTeamIds.has(teamId)) {
        const competitionCode = LEAGUE_TO_COMPETITION[r.meta.leagueId ?? -1] ?? null;
        // Verify the competition row exists (was it seeded?) — if not,
        // fall back to no competition link rather than FK error.
        let competitionId: string | null = null;
        if (competitionCode) {
          const c = await prisma.competition.findUnique({
            where: { id: competitionCode }, select: { id: true },
          });
          if (c) competitionId = competitionCode;
        }
        await prisma.team.upsert({
          where: { id: teamId },
          create: {
            id: teamId,
            name: r.meta.teamName ?? `Team ${teamId}`,
            shortName: (r.meta.teamName ?? `T${teamId}`).slice(0, 4).toUpperCase(),
            crestUrl: r.meta.teamLogo,
            competitionId,
          },
          update: {
            // Refresh logo + name on subsequent runs; don't overwrite
            // a competitionId we've already linked.
            name: r.meta.teamName ?? undefined,
            crestUrl: r.meta.teamLogo ?? undefined,
          },
        });
        knownTeamIds.add(teamId);
        createdTeams++;
      }
      // 2. Upsert player. Position best-effort from api-football's label.
      const pos = mapPosition(r.meta.position);
      await prisma.player.upsert({
        where: { id: playerId },
        create: {
          id: playerId,
          teamId,
          name: r.meta.name,
          position: pos,
          nationality: r.meta.nationality,
          photoUrl: r.meta.photo,
        },
        update: {
          // Keep name / position / photo current. Don't touch teamId on
          // updates — we'd otherwise yank loaned players between clubs.
          name: r.meta.name,
          position: pos,
          photoUrl: r.meta.photo ?? undefined,
          nationality: r.meta.nationality ?? undefined,
        },
      });
      // 3. Create the valuation with a floor price. The repricer will
      //    overwrite this in seconds once `npm run reprice:players` runs.
      const created = await prisma.playerValuation.create({
        data: {
          playerId,
          position: pos,
          price: defaultPriceFor(pos),
        },
        select: { id: true },
      });
      valuationId = created.id;
      valByPlayerId.set(playerId, valuationId);
      createdPlayers++;
    }

    await prisma.playerValuation.update({
      where: { id: valuationId },
      data: {
        seasonRating: avgRating,
        seasonAppearances: r.appearances || null,
        seasonGoals: r.goals || null,
        seasonAssists: r.assists || null,
        seasonMinutes: r.minutes || null,
        seasonSampled,
      },
    });
    updated++;
  }

  console.log(`[ingest-form] done.`);
  console.log(`  updated:        ${updated}`);
  console.log(`  created teams:  ${createdTeams}`);
  console.log(`  created players:${createdPlayers}`);
  console.log(`  skipped:        ${skipped} (no valuation, IMPORT_MISSING off)`);
  console.log(`  team unknown:   ${teamUnknown} (missing team data from upstream)`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
