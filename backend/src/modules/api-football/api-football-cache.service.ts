import { Inject, Injectable, Logger } from '@nestjs/common';
import Redis from 'ioredis';
import { REDIS_PUB } from '../../common/redis.module';
import {
  ApiFixture,
  ApiFixtureEvent,
  ApiFixturePlayersTeam,
  ApiFootballClient,
  ApiInjury,
  ApiLineup,
  ApiSquadResponse,
} from './api-football.client';

/**
 * TTL strategy for api-football data.
 *
 * Goal: ~95% reduction in upstream calls vs naive request-on-every-hit. Free
 * tier is 100 req/day; we want a single VM running for years on one tier.
 *
 * Categories:
 *   - **static** (24h): leagues, teams, squads, fixtures schedule. Changes
 *     happen once per season — manual refresh via cron acceptable.
 *   - **semi** (15m): standings, top scorers/assists, injuries. Recomputed
 *     after every match day, but stale-by-minutes is fine for the UI.
 *   - **live** (15s): live fixtures, fixture players (during a match), events,
 *     stats. Fast enough to feel real-time, slow enough to dedupe spammy reads.
 *   - **frozen** (no expiry): finished match data — these never change again.
 */
const TTL = {
  static:   24 * 60 * 60, // 24h
  semi:     15 * 60,      // 15m
  fixtureLive:  15,       // 15s during a live match
  fixtureFrozen: 0,       // no expiry — finished fixtures never change
} as const;

@Injectable()
export class ApiFootballCacheService {
  private readonly log = new Logger(ApiFootballCacheService.name);

  constructor(
    private readonly api: ApiFootballClient,
    @Inject(REDIS_PUB) private readonly redis: Redis,
  ) {}

  // ─── Generic helpers ──────────────────────────────────────────────────────

  /** Read JSON from Redis, or compute + cache on miss. ttl=0 means no expiry. */
  private async cached<T>(key: string, ttlSeconds: number, compute: () => Promise<T>): Promise<T> {
    try {
      const hit = await this.redis.get(key);
      if (hit) {
        return JSON.parse(hit) as T;
      }
    } catch (e) {
      this.log.warn(`cache read failed for ${key}: ${(e as Error).message}`);
    }
    const value = await compute();
    try {
      const payload = JSON.stringify(value);
      if (ttlSeconds > 0) {
        await this.redis.set(key, payload, 'EX', ttlSeconds);
      } else {
        await this.redis.set(key, payload);
      }
    } catch (e) {
      this.log.warn(`cache write failed for ${key}: ${(e as Error).message}`);
    }
    return value;
  }

  /** Invalidate one key. */
  async invalidate(key: string): Promise<void> {
    try {
      await this.redis.del(key);
    } catch (e) {
      this.log.warn(`cache invalidate failed for ${key}: ${(e as Error).message}`);
    }
  }

  /** Invalidate by glob pattern (e.g. 'apif:fixture:*'). Uses SCAN to avoid
   *  blocking the Redis server on large keyspaces. */
  async invalidatePattern(pattern: string): Promise<number> {
    let cursor = '0';
    let count = 0;
    try {
      do {
        const [next, keys] = await this.redis.scan(
          cursor,
          'MATCH',
          pattern,
          'COUNT',
          200,
        );
        cursor = next;
        if (keys.length) {
          await this.redis.del(...keys);
          count += keys.length;
        }
      } while (cursor !== '0');
    } catch (e) {
      this.log.warn(`cache scan failed for ${pattern}: ${(e as Error).message}`);
    }
    return count;
  }

  // ─── Cached endpoints ─────────────────────────────────────────────────────

  fixturesByLeagueSeason(leagueId: number, season: number): Promise<ApiFixture[]> {
    return this.cached(
      `apif:fixtures:l${leagueId}:s${season}`,
      TTL.static,
      () => this.api.fixturesByLeagueSeason(leagueId, season),
    );
  }

  /**
   * Live fixtures. Ultra-short TTL (15s) — multiple subscribers within the
   * window get the same cached payload, but the data still feels fresh.
   * Pass leagueId to scope to one competition.
   */
  liveFixtures(leagueId?: number): Promise<ApiFixture[]> {
    const key = leagueId ? `apif:live:l${leagueId}` : 'apif:live:all';
    return this.cached(key, TTL.fixtureLive, () => this.api.liveFixtures(leagueId));
  }

  listMatches(params: {
    league?: number;
    season?: number;
    date?: string;
    status?: string;
    team?: number;
    round?: string;
  }): Promise<ApiFixture[]> {
    const key = `apif:list:${JSON.stringify(params)}`;
    // Date-filtered queries cache differently:
    //   - past dates: never expire (results are frozen)
    //   - today: short TTL (matches may go live)
    //   - future dates: 1h (schedule may shift but rarely)
    let ttl = TTL.semi;
    if (params.date) {
      const d = new Date(params.date);
      const now = new Date();
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      if (d < today) ttl = TTL.fixtureFrozen;
      else if (d.getTime() === today.getTime()) ttl = TTL.fixtureLive;
      else ttl = 60 * 60; // 1h
    }
    return this.cached(key, ttl, () => this.api.listMatches(params));
  }

  teamsByLeagueSeason(leagueId: number, season: number) {
    return this.cached(
      `apif:teams:l${leagueId}:s${season}`,
      TTL.static,
      () => this.api.teamsByLeagueSeason(leagueId, season),
    );
  }

  squad(teamId: number): Promise<ApiSquadResponse[]> {
    return this.cached(
      `apif:squad:t${teamId}`,
      TTL.static,
      () => this.api.squad(teamId),
    );
  }

  /**
   * Fixture players — the data source for fantasy scoring. Live during the
   * match, frozen the moment FT is recorded. Caller is responsible for calling
   * [freezeFixture] once the upstream status flips to FT/AET/PEN.
   */
  fixturePlayers(fixtureId: number, isLive = true): Promise<ApiFixturePlayersTeam[]> {
    return this.cached(
      `apif:fxp:f${fixtureId}`,
      isLive ? TTL.fixtureLive : TTL.fixtureFrozen,
      () => this.api.fixturePlayers(fixtureId),
    );
  }

  fixtureEvents(fixtureId: number, isLive = true): Promise<ApiFixtureEvent[]> {
    return this.cached(
      `apif:fxe:f${fixtureId}`,
      isLive ? TTL.fixtureLive : TTL.fixtureFrozen,
      () => this.api.fixtureEvents(fixtureId),
    );
  }

  fixtureLineups(fixtureId: number): Promise<ApiLineup[]> {
    return this.cached(
      `apif:fxl:f${fixtureId}`,
      // Lineups change only at the kickoff announcement (~1h pre-match) and
      // when subs come on. 15s is fine.
      TTL.fixtureLive,
      () => this.api.fixtureLineups(fixtureId),
    );
  }

  fixtureStatistics(fixtureId: number, isLive = true) {
    return this.cached(
      `apif:fxs:f${fixtureId}`,
      isLive ? TTL.fixtureLive : TTL.fixtureFrozen,
      () => this.api.fixtureStatistics(fixtureId),
    );
  }

  /**
   * Once a fixture goes FT, freeze its derived caches at "no expiry" so we
   * never re-fetch frozen data again. Call from the poller when status flips.
   */
  async freezeFixture(fixtureId: number): Promise<void> {
    const keys = [
      `apif:fxp:f${fixtureId}`,
      `apif:fxe:f${fixtureId}`,
      `apif:fxl:f${fixtureId}`,
      `apif:fxs:f${fixtureId}`,
    ];
    try {
      // PERSIST removes the existing TTL → key never expires.
      await Promise.all(keys.map((k) => this.redis.persist(k)));
    } catch (e) {
      this.log.warn(`freezeFixture failed: ${(e as Error).message}`);
    }
  }

  injuries(leagueId: number, season: number): Promise<ApiInjury[]> {
    return this.cached(
      `apif:inj:l${leagueId}:s${season}`,
      TTL.semi,
      () => this.api.injuries(leagueId, season),
    );
  }

  topScorers(leagueId: number, season: number) {
    return this.cached(
      `apif:tops:l${leagueId}:s${season}`,
      60 * 60, // 1h
      () => this.api.topScorers(leagueId, season),
    );
  }

  topAssists(leagueId: number, season: number) {
    return this.cached(
      `apif:topa:l${leagueId}:s${season}`,
      60 * 60,
      () => this.api.topAssists(leagueId, season),
    );
  }

  prediction(fixtureId: number) {
    return this.cached(
      `apif:pred:f${fixtureId}`,
      6 * 60 * 60, // 6h — predictions are recalculated overnight
      () => this.api.prediction(fixtureId),
    );
  }

  headToHead(team1: number, team2: number, last = 10) {
    return this.cached(
      `apif:h2h:${team1}-${team2}:${last}`,
      6 * 60 * 60,
      () => this.api.headToHead(team1, team2, last),
    );
  }

  standings(leagueId: number, season: number) {
    return this.cached(
      `apif:std:l${leagueId}:s${season}`,
      TTL.semi,
      () => this.api.standings(leagueId, season),
    );
  }

  playerProfile(playerId: number) {
    return this.cached(
      `apif:pp:p${playerId}`,
      12 * 60 * 60, // 12h
      () => this.api.playerProfile(playerId),
    );
  }

  playerSeasonStats(playerId: number, season: number) {
    return this.cached(
      `apif:pss:p${playerId}:s${season}`,
      60 * 60,
      () => this.api.playerSeasonStats(playerId, season),
    );
  }

  // ─── Live-window awareness ────────────────────────────────────────────────
  // The poller writes the next live-window timestamp to Redis whenever it
  // computes the schedule. Other endpoints can consult it to decide whether
  // to attempt an upstream call at all.

  private static readonly NEXT_KICKOFF_KEY = 'apif:next-kickoff';
  private static readonly LAST_LIVE_AT_KEY = 'apif:last-live-at';

  /** Persist the next scheduled kickoff (millis epoch). */
  async setNextKickoff(at: Date | null): Promise<void> {
    if (at == null) {
      await this.redis.del(ApiFootballCacheService.NEXT_KICKOFF_KEY);
    } else {
      await this.redis.set(
        ApiFootballCacheService.NEXT_KICKOFF_KEY,
        at.getTime().toString(),
      );
    }
  }

  /** Read the next scheduled kickoff. */
  async getNextKickoff(): Promise<Date | null> {
    const raw = await this.redis.get(ApiFootballCacheService.NEXT_KICKOFF_KEY);
    if (!raw) return null;
    const n = Number(raw);
    if (Number.isNaN(n)) return null;
    return new Date(n);
  }

  /** Heartbeat — when did we last see at least one live fixture? */
  async markLive(): Promise<void> {
    await this.redis.set(
      ApiFootballCacheService.LAST_LIVE_AT_KEY,
      Date.now().toString(),
      'EX',
      4 * 60 * 60,
    );
  }

  /** Returns true if there's a fixture either live now or within ±[bufferMin]
   *  minutes of a scheduled kickoff. Off-window callers can skip upstream. */
  async isLiveWindow(bufferMin = 15): Promise<boolean> {
    const next = await this.getNextKickoff();
    if (!next) return false;
    const now = Date.now();
    const window = bufferMin * 60_000;
    return next.getTime() <= now + window && next.getTime() >= now - 4 * 60 * 60_000;
  }

  /** Quota visibility for ops. */
  getQuota() {
    return this.api.getQuota();
  }
}
