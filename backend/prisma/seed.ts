/**
 * One-shot seed for WC 2026. Pulls from api-football and writes:
 *   - Competition + Teams + Players (squads)
 *   - Matches (fixtures)
 *   - PlayerValuation (default prices, refined by pricing cron after first gameweek)
 *   - FantasyTournament + FantasyGameweeks (one per matchday + knockout round)
 *   - CardTemplates for Global Cup prize tiers + base sticker album seeds
 *   - GlobalCupPrize rows mapping rank ranges → prize templates
 *
 * Idempotent — safe to re-run. Re-running won't duplicate teams/players/fixtures.
 * Run with: `npm run seed`
 */

import { PrismaClient, PlayerPosition, CardRarity, FantasyFormat, MatchStatus } from '@prisma/client';
import axios, { AxiosError } from 'axios';
import 'dotenv/config';

const prisma = new PrismaClient();

// ─────────────────────────────────────────────────────────────────────────────
// Inlined from src/modules/api-football/api-football.config.ts
// Kept here so the seed is self-contained — the runtime Docker image only
// ships dist/, not src/, so ts-node can't reach into the source tree at run
// time. If you change the canonical version in src/, sync this too.
// ─────────────────────────────────────────────────────────────────────────────
const RAPIDAPI_HOST = 'api-football-v1.p.rapidapi.com';
function resolveApiFootballConfig() {
  const key = process.env.API_FOOTBALL_KEY;
  if (!key) throw new Error('API_FOOTBALL_KEY is required');
  const provider = (process.env.API_FOOTBALL_PROVIDER ?? 'direct').toLowerCase();
  if (provider === 'rapidapi') {
    return {
      baseURL: process.env.API_FOOTBALL_BASE ?? `https://${RAPIDAPI_HOST}/v3`,
      headers: { 'x-rapidapi-host': RAPIDAPI_HOST, 'x-rapidapi-key': key },
    };
  }
  return {
    baseURL: process.env.API_FOOTBALL_BASE ?? 'https://v3.football.api-sports.io',
    headers: { 'x-apisports-key': key },
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Inlined from src/modules/api-football/status-map.ts
// ─────────────────────────────────────────────────────────────────────────────
function mapApiFootballStatus(short: string): MatchStatus {
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

const LEAGUE = Number(process.env.API_FOOTBALL_WC_LEAGUE_ID ?? '1');
const SEASON = Number(process.env.API_FOOTBALL_WC_SEASON   ?? '2026');

// On the RapidAPI free tier the per-minute cap is tight (≈30/min). The seed
// makes ~50 requests in sequence. Add a small floor between calls to stay
// safely under the limit. On Pro tier (450/min direct or RapidAPI) you can
// drop this to 0 for a faster seed.
const REQUEST_DELAY_MS = Number(process.env.SEED_REQUEST_DELAY_MS ?? '250');
const MAX_RETRIES = 5;

// Resolves direct-vs-RapidAPI auth from env in one place.
const api = axios.create({ ...resolveApiFootballConfig(), timeout: 30_000 });

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/**
 * Single-source helper. Handles:
 *   - Both response envelopes (direct: `{errors:...}`; RapidAPI proxy: `{message:...}`)
 *   - HTTP 429 retries with exponential backoff that respects the
 *     `retry-after` header when present
 *   - Per-minute rate-limit ceiling read from response headers
 *   - A configurable inter-request delay so free-tier users don't melt their quota
 */
async function fetch<T>(path: string, params: Record<string, string | number>): Promise<T[]> {
  let lastErr: unknown;
  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    try {
      if (attempt > 0) {
        const backoffMs = Math.min(60_000, 1_000 * 2 ** (attempt - 1));
        console.warn(`  retry ${attempt}/${MAX_RETRIES} for ${path} after ${backoffMs}ms`);
        await sleep(backoffMs);
      }
      const res = await api.get(path, { params });
      const data = res.data;

      // RapidAPI proxy error (e.g. invalid key, monthly quota exceeded).
      if (typeof data?.message === 'string' && !Array.isArray(data?.response)) {
        throw new Error(`api-football (rapidapi) error: ${data.message}`);
      }
      // Direct (api-sports.io) error envelope.
      const hasErrors = Array.isArray(data.errors)
        ? data.errors.length > 0
        : data.errors && Object.keys(data.errors).length > 0;
      if (hasErrors) {
        throw new Error(`api-football errors: ${JSON.stringify(data.errors)}`);
      }

      // Log quota every ~10 requests so a slow squad walk doesn't look stuck.
      const perMin = res.headers['x-ratelimit-remaining'];
      const daily  = res.headers['x-ratelimit-requests-remaining'];
      if (perMin || daily) {
        process.stdout.write(
          `  ✓ ${path}  (quota: ${perMin ?? '?'}/min · ${daily ?? '?'}/day)        \r`,
        );
      }

      if (REQUEST_DELAY_MS) await sleep(REQUEST_DELAY_MS);
      return (data.response ?? []) as T[];
    } catch (err) {
      lastErr = err;
      // Only retry on 429 or transient 5xx / network errors.
      const isAxios = axios.isAxiosError(err);
      const status = isAxios ? (err as AxiosError).response?.status : 0;
      const retryable = !status || status === 429 || (status >= 500 && status < 600);
      if (!retryable) break;

      // Honour Retry-After when present (RapidAPI sends seconds).
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

function mapApiPosition(label: string): PlayerPosition {
  const l = label.toLowerCase();
  if (l.startsWith('goal')) return 'GK';
  if (l.startsWith('def'))  return 'DEF';
  if (l.startsWith('att') || l.startsWith('forward')) return 'FWD';
  return 'MID';
}

function defaultPriceFor(position: PlayerPosition): number {
  // Flat starting valuations; pricing cron refines after the first gameweek.
  switch (position) {
    case 'GK':  return 5.0;
    case 'DEF': return 5.5;
    case 'MID': return 6.5;
    case 'FWD': return 7.5;
  }
}

// Status mapping is shared with the realtime poller via
// `src/modules/api-football/status-map.ts` so seed + poll always agree.
const statusMap = mapApiFootballStatus;

async function seedCompetition() {
  console.log('▸ Competition WC2026');
  const ts = new Date(`${SEASON}-06-11T00:00:00Z`);
  await prisma.competition.upsert({
    where: { id: 'WC2026' },
    create: {
      id: 'WC2026', name: 'FIFA World Cup 2026', type: 'tournament',
      season: String(SEASON), startsAt: ts, endsAt: new Date(`${SEASON}-07-19T23:59:59Z`),
      emblemUrl: null,
    },
    update: {},
  });
}

async function seedTeamsAndPlayers() {
  console.log('▸ Teams');
  type ApiTeam = { team: { id: number; name: string; code: string | null; country: string; logo: string } };
  const teams = await fetch<ApiTeam>('/teams', { league: LEAGUE, season: SEASON });
  console.log(`  ${teams.length} teams`);

  for (const t of teams) {
    await prisma.team.upsert({
      where: { id: String(t.team.id) },
      create: {
        id: String(t.team.id),
        competitionId: 'WC2026',
        name: t.team.name,
        shortName: t.team.code ?? t.team.name.slice(0, 3).toUpperCase(),
        countryCode: t.team.code,
        crestUrl: t.team.logo,
      },
      update: { competitionId: 'WC2026', crestUrl: t.team.logo },
    });

    console.log(`  squad: ${t.team.name}`);
    const squads = await fetch<{ team: { id: number }; players: Array<{ id: number; name: string; age: number | null; number: number | null; position: string; photo: string }> }>(
      '/players/squads', { team: t.team.id },
    );
    const players = squads[0]?.players ?? [];

    for (const p of players) {
      const pos = mapApiPosition(p.position);
      await prisma.player.upsert({
        where: { id: String(p.id) },
        create: {
          id: String(p.id),
          teamId: String(t.team.id),
          name: p.name,
          shirtNumber: p.number,
          position: pos,
          photoUrl: p.photo,
        },
        update: { teamId: String(t.team.id), photoUrl: p.photo, shirtNumber: p.number, position: pos },
      });
      await prisma.playerValuation.upsert({
        where: { playerId: String(p.id) },
        create: { playerId: String(p.id), price: defaultPriceFor(pos), recentForm: 0, position: pos },
        update: { position: pos },
      });
    }
  }
}

async function seedFixtures() {
  console.log('▸ Fixtures');
  type ApiFixture = {
    fixture: { id: number; date: string; venue: { name: string | null }; status: { short: string; elapsed: number | null } };
    league:  { round: string };
    teams:   { home: { id: number }; away: { id: number } };
    goals:   { home: number | null; away: number | null };
    score:   { penalty: { home: number | null; away: number | null } };
  };
  const fixtures = await fetch<ApiFixture>('/fixtures', { league: LEAGUE, season: SEASON });
  console.log(`  ${fixtures.length} fixtures`);

  for (const f of fixtures) {
    await prisma.match.upsert({
      where: { id: String(f.fixture.id) },
      create: {
        id: String(f.fixture.id),
        competitionId: 'WC2026',
        homeTeamId: String(f.teams.home.id),
        awayTeamId: String(f.teams.away.id),
        kickoffAt: new Date(f.fixture.date),
        status: statusMap(f.fixture.status.short),
        minute: f.fixture.status.elapsed,
        homeScore: f.goals.home ?? 0,
        awayScore: f.goals.away ?? 0,
        homePenalties: f.score.penalty.home,
        awayPenalties: f.score.penalty.away,
        stage: f.league.round,
        venue: f.fixture.venue.name,
      },
      update: {
        status: statusMap(f.fixture.status.short),
        minute: f.fixture.status.elapsed,
        homeScore: f.goals.home ?? 0,
        awayScore: f.goals.away ?? 0,
        stage: f.league.round,
      },
    });
  }
  return fixtures;
}

async function seedFantasyTournamentAndGameweeks(fixtures: Array<{ fixture: { id: number; date: string }; league: { round: string } }>) {
  console.log('▸ Fantasy tournament + gameweeks');
  const t = await prisma.fantasyTournament.upsert({
    where: { slug: 'wc2026-global-cup' },
    create: {
      slug: 'wc2026-global-cup',
      competitionId: 'WC2026',
      name: 'FootballMojo Global Cup 2026',
      format: 'GLOBAL_CUP' as FantasyFormat,
      budget: 100,
      description: 'Free-to-play. 100-pt budget. Draft 8 players (2 GK · 2 DEF · 2 MID · 2 FWD). Captain doubles points.',
      startsAt: new Date(`${SEASON}-06-11T00:00:00Z`),
      endsAt:   new Date(`${SEASON}-07-19T23:59:59Z`),
    },
    update: {},
  });

  // Group fixtures by api-football "round" string (e.g. "Group Stage - 1", "Round of 16").
  const byRound = new Map<string, typeof fixtures>();
  for (const f of fixtures) {
    const arr = byRound.get(f.league.round) ?? [];
    arr.push(f);
    byRound.set(f.league.round, arr);
  }
  let n = 0;
  const roundsSorted = [...byRound.entries()].sort(
    ([, a], [, b]) => new Date(a[0].fixture.date).getTime() - new Date(b[0].fixture.date).getTime(),
  );
  for (const [round, group] of roundsSorted) {
    n++;
    const sorted = group.slice().sort((a, b) => new Date(a.fixture.date).getTime() - new Date(b.fixture.date).getTime());
    const lockAt = new Date(sorted[0]!.fixture.date);
    const endsAt = new Date(new Date(sorted.at(-1)!.fixture.date).getTime() + 3 * 60 * 60_000); // last KO + 3h
    await prisma.fantasyGameweek.upsert({
      where: { tournamentId_number: { tournamentId: t.id, number: n } },
      create: {
        tournamentId: t.id,
        number: n,
        name: round,
        lockAt,
        endsAt,
        matchIds: sorted.map((f) => String(f.fixture.id)),
      },
      update: {
        name: round,
        lockAt,
        endsAt,
        matchIds: sorted.map((f) => String(f.fixture.id)),
      },
    });
  }
  return t;
}

async function seedPrizeTemplatesAndPrizes(tournamentId: string) {
  console.log('▸ Global Cup prize tiers + card templates');
  // Define prize tiers + supply (Sorare 2022 was 100k; we scale by rarity).
  const tiers = [
    { rankFrom: 1,     rankTo: 1,     rarity: 'ICONIC'    as CardRarity, totalSupply: 1,    edition: 'WC2026-CUP-CHAMPION',  description: 'Champion of FootballMojo Global Cup 2026' },
    { rankFrom: 2,     rankTo: 10,    rarity: 'LEGENDARY' as CardRarity, totalSupply: 9,    edition: 'WC2026-CUP-LEGENDARY', description: 'Top 10 of the Global Cup' },
    { rankFrom: 11,    rankTo: 100,   rarity: 'EPIC'      as CardRarity, totalSupply: 90,   edition: 'WC2026-CUP-EPIC',      description: 'Top 100 of the Global Cup' },
    { rankFrom: 101,   rankTo: 1000,  rarity: 'RARE'      as CardRarity, totalSupply: 900,  edition: 'WC2026-CUP-RARE',      description: 'Top 1,000 of the Global Cup' },
    { rankFrom: 1001,  rankTo: 10000, rarity: 'UNCOMMON'  as CardRarity, totalSupply: 9000, edition: 'WC2026-CUP-UNCOMMON',  description: 'Top 10,000 of the Global Cup' },
  ];
  for (const t of tiers) {
    const tpl = await prisma.cardTemplate.upsert({
      where: { id: t.edition },
      create: {
        id: t.edition,
        edition: t.edition,
        rarity: t.rarity,
        totalSupply: t.totalSupply,
        baseStats: {},
        artUrl: `https://cdn.footballmojo.app/cards/${t.edition.toLowerCase()}.png`,
        frameStyle: t.rarity === 'ICONIC' ? 'trophy' : 'holographic',
        giftableOnly: true,
        purchasable: false,
      },
      update: { totalSupply: t.totalSupply, rarity: t.rarity },
    });
    const existing = await prisma.globalCupPrize.findFirst({
      where: { tournamentId, rankFrom: t.rankFrom },
    });
    if (existing) {
      await prisma.globalCupPrize.update({
        where: { id: existing.id },
        data: { rankTo: t.rankTo, description: t.description, cardTemplateId: tpl.id },
      });
    } else {
      await prisma.globalCupPrize.create({
        data: {
          tournamentId,
          rankFrom: t.rankFrom,
          rankTo: t.rankTo,
          description: t.description,
          cardTemplateId: tpl.id,
        },
      });
    }
  }
}

async function main() {
  if (!process.env.API_FOOTBALL_KEY) {
    throw new Error('Set API_FOOTBALL_KEY in your env to run the seed.');
  }
  await seedCompetition();
  await seedTeamsAndPlayers();
  const fixtures = await seedFixtures();
  const tournament = await seedFantasyTournamentAndGameweeks(fixtures);
  await seedPrizeTemplatesAndPrizes(tournament.id);
  console.log('✓ Seed complete');
}

main()
  .then(() => process.exit(0))
  .catch((e) => { console.error(e); process.exit(1); });
