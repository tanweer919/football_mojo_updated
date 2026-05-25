import { Inject, Injectable, Logger } from '@nestjs/common';
import { Match, MatchStatus } from '@prisma/client';
import Redis from 'ioredis';
import { PrismaService } from '../../common/prisma.service';
import { REDIS_PUB } from '../../common/redis.module';
import { ApiFixture } from '../api-football/api-football.client';
import { mapApiFootballStatus } from '../api-football/status-map';
import { competitionIdForApi } from '../competitions/leagues.config';
import { CHANNELS, MatchUpdatePayload } from './scores.events';

const REDIS_KEYS = {
  liveMatchIds: 'live:match-ids',
  matchSnap:    (id: string) => `match:${id}:snap`,
  fixturesDay:  (day: string) => `fixtures:${day}`,
};

@Injectable()
export class ScoresService {
  private readonly log = new Logger(ScoresService.name);

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

    for (const u of upstream) {
      const id = String(u.fixture.id);
      const status = mapApiFootballStatus(u.fixture.status.short);
      const homeScore     = u.goals.home ?? 0;
      const awayScore     = u.goals.away ?? 0;
      const homePenalties = u.score.penalty.home;
      const awayPenalties = u.score.penalty.away;
      const minute        = u.fixture.status.elapsed;

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
        existing.homePenalties !== homePenalties ||
        existing.awayPenalties !== awayPenalties;

      if (!dirty) continue;
      changed++;

      const updated = await this.prisma.match.update({
        where: { id },
        data: { status, minute, homeScore, awayScore, homePenalties, awayPenalties },
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

      return await this.prisma.match.create({
        data: {
          id: String(u.fixture.id),
          competitionId,
          homeTeamId: String(u.teams.home.id),
          awayTeamId: String(u.teams.away.id),
          kickoffAt: new Date(u.fixture.date),
          status, minute, homeScore, awayScore, homePenalties, awayPenalties,
          stage: u.league.round,
          venue: u.fixture.venue?.name ?? null,
        },
      });
    } catch (err) {
      this.log.warn(`tryCreateMatch failed for fixture=${u.fixture.id}: ${(err as Error).message}`);
      return null;
    }
  }

  private async publishUpdate(m: Match) {
    const payload: MatchUpdatePayload = {
      id: m.id,
      status: m.status,
      minute: m.minute,
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
