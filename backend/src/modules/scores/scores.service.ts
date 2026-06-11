import { Inject, Injectable, Logger } from '@nestjs/common';
import { Match, MatchStatus } from '@prisma/client';
import Redis from 'ioredis';
import { PrismaService } from '../../common/prisma.service';
import { REDIS_PUB } from '../../common/redis.module';
import { ApiFixture } from '../api-football/api-football.client';
import { mapApiFootballStatus } from '../api-football/status-map';
import { competitionIdForApi } from '../competitions/leagues.config';
import { CHANNELS, MatchUpdatePayload } from './scores.events';
import { fixturePairKey } from './wc-team-aliases';

const WC_COMPETITION_ID = 'WC2026';

const REDIS_KEYS = {
  liveMatchIds: 'live:match-ids',
  matchSnap:    (id: string) => `match:${id}:snap`,
  fixturesDay:  (day: string) => `fixtures:${day}`,
};

@Injectable()
export class ScoresService {
  private readonly log = new Logger(ScoresService.name);
  // Run the existing-duplicate sweep once per process, on the first ingest.
  private wcSwept = false;

  constructor(
    private readonly prisma: PrismaService,
    @Inject(REDIS_PUB) private readonly pub: Redis,
  ) {}

  /**
   * Ingest an api-football snapshot, detect deltas, persist + publish.
   * Returns the count of matches that actually changed so the poller can adapt cadence.
   *
   * Rule of thumb on score reads:
   *   - Live matches (1H/2H/HT/ET/BT/P): use `goals.home/away` — these are the running totals.
   *   - Finished (FT/AET/PEN): use `score.fulltime` for the open-play total, plus
   *     `score.penalty` if the match went to a shootout.
   *   - Half-time: `score.halftime` is informational only; we still want the running total.
   * `goals` is always the running total so it's safe across every state.
   */
  async ingestSnapshot(upstream: ApiFixture[]): Promise<{ changed: number; live: number; finishedFixtureIds: number[] }> {
    let changed = 0;
    let live = 0;
    const liveIds: string[] = [];
    const finishedFixtureIds: number[] = [];

    // First ingest after boot: clear any pre-existing seed/api duplicates.
    if (!this.wcSwept) {
      this.wcSwept = true;
      await this.reconcileWcSeedDuplicates().catch((e) =>
        this.log.warn(`WC seed sweep failed: ${(e as Error).message}`),
      );
    }

    for (const u of upstream) {
      const id = String(u.fixture.id);
      const status = mapApiFootballStatus(u.fixture.status.short);
      const homeScore     = u.goals.home ?? 0;
      const awayScore     = u.goals.away ?? 0;
      const homePenalties = u.score.penalty.home;
      const awayPenalties = u.score.penalty.away;
      const minute        = u.fixture.status.elapsed;
      const minuteExtra   = u.fixture.status.extra;

      if (status === 'LIVE' || status === 'HALF_TIME') {
        live++;
        liveIds.push(id);
      }

      const existing = await this.prisma.match.findUnique({ where: { id } });
      if (!existing) {
        // Newly-discovered fixture (knockout pairings drawn mid-tournament,
        // freshly added club fixture, etc.). Create on the fly so we don't have
        // to re-seed every time. Skips silently when:
        //   - the league isn't in our LEAGUES config (we don't track it)
        //   - the upstream payload is missing team ids
        const created = await this.tryCreateMatch(u, status, homeScore, awayScore, homePenalties, awayPenalties, minute);
        if (created) {
          changed++;
          await this.publishUpdate(created);
        }
        continue;
      }

      const dirty =
        existing.status !== status ||
        existing.homeScore !== homeScore ||
        existing.awayScore !== awayScore ||
        existing.minute !== minute ||
        existing.minuteExtra !== minuteExtra ||
        existing.homePenalties !== homePenalties ||
        existing.awayPenalties !== awayPenalties;

      if (!dirty) continue;
      changed++;

      const updated = await this.prisma.match.update({
        where: { id },
        data: { status, minute, minuteExtra, homeScore, awayScore, homePenalties, awayPenalties },
      });

      // Flag transitions to FT so the poller can freeze the upstream caches.
      if (existing.status !== 'FINISHED' && status === 'FINISHED') {
        finishedFixtureIds.push(u.fixture.id);
      }

      await this.publishUpdate(updated);

      // Goal-edge detection → synthesize a GOAL event so the FCM dispatcher fires
      // even if /fixtures/events hasn't caught up yet.
      if (homeScore > existing.homeScore) {
        await this.recordSynthEvent(id, minute ?? 0, 'GOAL', existing.homeTeamId);
      }
      if (awayScore > existing.awayScore) {
        await this.recordSynthEvent(id, minute ?? 0, 'GOAL', existing.awayTeamId);
      }
    }

    await this.pub.set(REDIS_KEYS.liveMatchIds, JSON.stringify(liveIds), 'EX', 300);
    return { changed, live, finishedFixtureIds };
  }

  /**
   * Best-effort INSERT for a fixture we've never seen. Used by the live ingest
   * to absorb new matches discovered from `live=all` (e.g. a club kickoff that
   * wasn't in the last seed run). Returns null when:
   *   - league isn't configured (intentional skip — we don't track everything)
   *   - upsert hits a foreign-key issue (missing team rows)
   *
   * Teams are upserted from the upstream payload (id + name + logo), so we
   * never insert a Match without its FK targets.
   */
  private async tryCreateMatch(
    u: ApiFixture,
    status: MatchStatus,
    homeScore: number,
    awayScore: number,
    homePenalties: number | null,
    awayPenalties: number | null,
    minute: number | null,
  ): Promise<Match | null> {
    const competitionId = competitionIdForApi(u.league.id);
    if (!competitionId) return null; // league outside our config — skip
    if (!u.teams?.home?.id || !u.teams?.away?.id) return null;

    try {
      // Ensure both team rows exist. Use the cheap fields available on the
      // fixture payload — if the team is later picked up by the league seed
      // we'll get richer data (countryCode, shortName) on the next run.
      await this.prisma.team.upsert({
        where: { id: String(u.teams.home.id) },
        create: {
          id: String(u.teams.home.id),
          competitionId,
          name: u.teams.home.name,
          shortName: u.teams.home.name.slice(0, 3).toUpperCase(),
          crestUrl: u.teams.home.logo,
        },
        update: { crestUrl: u.teams.home.logo },
      });
      await this.prisma.team.upsert({
        where: { id: String(u.teams.away.id) },
        create: {
          id: String(u.teams.away.id),
          competitionId,
          name: u.teams.away.name,
          shortName: u.teams.away.name.slice(0, 3).toUpperCase(),
          crestUrl: u.teams.away.logo,
        },
        update: { crestUrl: u.teams.away.logo },
      });

      const created = await this.prisma.match.create({
        data: {
          id: String(u.fixture.id),
          competitionId,
          homeTeamId: String(u.teams.home.id),
          awayTeamId: String(u.teams.away.id),
          kickoffAt: new Date(u.fixture.date),
          status, minute, homeScore, awayScore, homePenalties, awayPenalties,
          minuteExtra: u.fixture.status.extra,
          stage: u.league.round,
          venue: u.fixture.venue?.name ?? null,
        },
      });

      // This is the real (numeric-id) fixture. If a hand-seeded WC placeholder
      // exists for the same nations, drop it so the match isn't duplicated.
      // Best-effort — never let reconciliation break ingest.
      if (competitionId === WC_COMPETITION_ID) {
        await this.dropSeedDuplicateFor(u.teams.home.name, u.teams.away.name, created.id)
          .catch((e) => this.log.warn(`seed reconcile failed: ${(e as Error).message}`));
      }
      return created;
    } catch (err) {
      this.log.warn(`tryCreateMatch failed for fixture=${u.fixture.id}: ${(err as Error).message}`);
      return null;
    }
  }

  /**
   * Authoritative "should we be polling?" signal, straight from the DB: any
   * match currently LIVE/HALF_TIME, OR any non-finished match that kicked off
   * in the last ~3.5h (so a fixture in play but not yet flipped still counts).
   * The poller ORs this with the kickoff-proximity window so it can never idle
   * mid-match — and recovers a frozen match on the very next tick regardless of
   * the Redis live heartbeat.
   */
  async hasActiveMatches(): Promise<boolean> {
    const now = Date.now();
    const n = await this.prisma.match.count({
      where: {
        OR: [
          { status: { in: ['LIVE', 'HALF_TIME'] } },
          {
            status: { notIn: ['FINISHED', 'CANCELLED', 'POSTPONED'] },
            kickoffAt: {
              gte: new Date(now - 3.5 * 60 * 60_000),
              lte: new Date(now),
            },
          },
        ],
      },
    });
    return n > 0;
  }

  /**
   * Delete any hand-seeded WC placeholder rows (`WC2026-*` ids) whose two
   * nations match the given pair, keeping `keepId` (the real numeric fixture).
   * Names are reconciled through the alias map, so api-football labels like
   * "Ivory Coast" / "South Korea" still match the seed's "Côte d'Ivoire" /
   * "Korea Republic". Cascades clean up the placeholder's events/predictions.
   */
  private async dropSeedDuplicateFor(homeName: string, awayName: string, keepId: string): Promise<void> {
    const want = fixturePairKey(homeName, awayName);
    const seeds = await this.prisma.match.findMany({
      where: { competitionId: WC_COMPETITION_ID, id: { startsWith: 'WC2026-' } },
      select: { id: true, homeTeam: { select: { name: true } }, awayTeam: { select: { name: true } } },
    });
    const dupes = seeds
      .filter((m) => m.id !== keepId && fixturePairKey(m.homeTeam.name, m.awayTeam.name) === want)
      .map((m) => m.id);
    if (dupes.length) {
      await this.prisma.match.deleteMany({ where: { id: { in: dupes } } });
      this.log.log(`reconciled WC seed placeholder(s) for ${homeName} vs ${awayName} → ${keepId}`);
    }
  }

  /**
   * One-time sweep to clear placeholder/api duplicates already sitting in the
   * DB (rows created before reconciliation existed). For every nation pair that
   * has BOTH a real numeric-id row and a `WC2026-*` seed row, drop the seed row.
   * Idempotent and safe to run on every boot — only ~64 WC rows are scanned.
   */
  async reconcileWcSeedDuplicates(): Promise<number> {
    const rows = await this.prisma.match.findMany({
      where: { competitionId: WC_COMPETITION_ID },
      select: { id: true, homeTeam: { select: { name: true } }, awayTeam: { select: { name: true } } },
    });
    const realPairs = new Set<string>();
    for (const m of rows) {
      if (/^\d+$/.test(m.id)) realPairs.add(fixturePairKey(m.homeTeam.name, m.awayTeam.name));
    }
    const stale = rows
      .filter((m) => m.id.startsWith('WC2026-') && realPairs.has(fixturePairKey(m.homeTeam.name, m.awayTeam.name)))
      .map((m) => m.id);
    if (stale.length) {
      await this.prisma.match.deleteMany({ where: { id: { in: stale } } });
      this.log.log(`reconciled ${stale.length} stale WC seed duplicate(s)`);
    }
    return stale.length;
  }

  private async publishUpdate(m: Match) {
    const payload: MatchUpdatePayload = {
      id: m.id,
      status: m.status,
      minute: m.minute,
      minuteExtra: m.minuteExtra,
      homeScore: m.homeScore,
      awayScore: m.awayScore,
      homePenalties: m.homePenalties,
      awayPenalties: m.awayPenalties,
      updatedAt: m.updatedAt.toISOString(),
    };
    await this.pub.set(REDIS_KEYS.matchSnap(m.id), JSON.stringify(payload), 'EX', 86_400);
    await this.pub.publish(CHANNELS.matchUpdate(m.id), JSON.stringify(payload));
    await this.pub.publish(CHANNELS.fixturesUpdate, JSON.stringify(payload));
  }

  private async recordSynthEvent(
    matchId: string,
    minute: number,
    type: 'GOAL',
    teamId: string,
  ) {
    const evt = await this.prisma.matchEvent.create({
      data: { matchId, minute, type, teamId, detail: null },
    });
    await this.pub.publish(
      CHANNELS.matchEvent(matchId),
      JSON.stringify({
        id: evt.id,
        matchId,
        minute,
        type,
        teamId,
        playerId: null,
        detail: null,
        createdAt: evt.createdAt.toISOString(),
      }),
    );
  }

  // Read-side helpers (used by REST controller — short Redis TTL absorbs read spikes).
  async getLive() {
    const ids: string[] = JSON.parse((await this.pub.get(REDIS_KEYS.liveMatchIds)) || '[]');
    if (!ids.length) return [];
    return this.prisma.match.findMany({
      where: { id: { in: ids } },
      include: { homeTeam: true, awayTeam: true },
      orderBy: { kickoffAt: 'asc' },
    });
  }

  async getFixturesForDay(day: string) {
    const cached = await this.pub.get(REDIS_KEYS.fixturesDay(day));
    if (cached) return JSON.parse(cached);
    const start = new Date(`${day}T00:00:00Z`);
    const end = new Date(`${day}T23:59:59Z`);
    const rows = await this.prisma.match.findMany({
      where: { kickoffAt: { gte: start, lte: end } },
      include: { homeTeam: true, awayTeam: true, competition: true },
      orderBy: { kickoffAt: 'asc' },
    });
    await this.pub.set(REDIS_KEYS.fixturesDay(day), JSON.stringify(rows), 'EX', 60);
    return rows;
  }

  async getMatchDetail(id: string) {
    return this.prisma.match.findUnique({
      where: { id },
      include: {
        homeTeam: true,
        awayTeam: true,
        competition: true,
        events: { orderBy: { minute: 'asc' } },
      },
    });
  }

  async getStandings(competitionId: string) {
    return this.prisma.group.findMany({
      where: { competitionId },
      include: { standings: { include: { team: true }, orderBy: { position: 'asc' } } },
      orderBy: { name: 'asc' },
    });
  }
}
