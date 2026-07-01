import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApiFootballCacheService } from '../api-football/api-football-cache.service';
import { ApiFootballClient, ApiFixture } from '../api-football/api-football.client';
import { activeLeagueIds, LeagueConfig } from '../competitions/leagues.config';
import { ScoresService } from './scores.service';

/**
 * Multi-league realtime polling loop, backed by api-football v3.
 *
 * The single global tick alternates between two upstream calls:
 *   - Live tick:  `GET /fixtures?live=all` — returns every match in progress
 *     across every competition. We filter to the league set we track.
 *   - Idle tick:  `GET /fixtures?league={id}&season={s}&date=YYYY-MM-DD` for
 *     each tracked league in parallel. Used to flip SCHEDULED → LIVE on
 *     kickoff and to pick up new fixtures on knockout draws / re-schedules.
 *
 * Live-window aware:
 *   - When ≥1 fixture is live OR within ±15min of kickoff: poll every [liveMs] (15s).
 *   - Otherwise: long sleep until the next kickoff (capped at idleMs).
 *
 * Each tick consumes 1 (live) or N (idle, parallel) api-football requests where
 * N = number of tracked leagues. Cache layer absorbs duplicate reads from the
 * REST controller during the same window.
 */
@Injectable()
export class ScoresPoller implements OnModuleInit {
  private readonly log = new Logger(ScoresPoller.name);
  private readonly liveMs: number;      // cadence while ≥1 match is live (fast)
  private readonly watchMs: number;     // cadence in the run-up to kickoff (no live yet)
  private readonly preWindowMs: number; // start watching this long before kickoff
  private readonly maxIdleMs: number;   // longest single sleep when nothing is near
  private readonly refreshEveryMs: number; // min gap between full-schedule refreshes
  private readonly leagues: LeagueConfig[];
  private timer: NodeJS.Timeout | null = null;
  private stopped = false;
  private lastScheduleRefresh = 0;

  constructor(
    cfg: ConfigService,
    private readonly api: ApiFootballClient,
    private readonly cache: ApiFootballCacheService,
    private readonly scores: ScoresService,
  ) {
    this.liveMs = +(cfg.get('POLL_INTERVAL_LIVE_MS') ?? 15_000);
    this.watchMs = +(cfg.get('POLL_INTERVAL_WATCH_MS') ?? 60_000);
    // Wake ~1h before kickoff so lineups (published ~1h out) are ready and we
    // catch the start; matches can run long (ET + penalties) — the live=all
    // window handles that since a match stays "live" until api ends it.
    this.preWindowMs = +(cfg.get('POLL_PRE_WINDOW_MS') ?? 65 * 60_000);
    // Longest we'll sleep with no match near. Kept long on purpose — waking here
    // costs nothing (schedule refresh is throttled separately), so a long sleep
    // just avoids needless CPU. Dedicated var so a legacy POLL_INTERVAL_IDLE_MS
    // can't force frequent wakes.
    this.maxIdleMs = Math.max(+(cfg.get('POLL_MAX_IDLE_MS') ?? 60 * 60_000), this.watchMs);
    this.refreshEveryMs = +(cfg.get('POLL_SCHEDULE_REFRESH_MS') ?? 2 * 60 * 60_000);
    this.leagues = activeLeagueIds(cfg.get<string>('POLL_LEAGUE_IDS'));
    this.log.log(
      `Poller will track ${this.leagues.length} league(s): ${this.leagues.map((l) => l.code).join(', ')}`,
    );
  }

  onModuleInit() {
    if (process.env.WORKER_MODE !== 'true' && process.env.NODE_ENV === 'production') {
      this.log.log('Skipping poller — WORKER_MODE not set');
      return;
    }
    // Backfill group standings from existing results on boot — they're seeded
    // at 0 and only recomputed on subsequent full-time transitions, so without
    // this the table stays stale for matches that finished before this deploy.
    this.scores
      .recomputeStandings()
      .then(() => this.scores.reconcileKnockout())
      .catch((e) => this.log.warn(`standings/knockout backfill failed: ${(e as Error).message}`));
    this.tick().catch((e) => this.log.error('initial tick failed', e));
  }

  async tick() {
    if (this.stopped) return;
    const start = Date.now();
    let nextDelay = this.maxIdleMs;

    try {
      // Step 0: Reap any match frozen in a live state — ended but dropped from
      // `live=all` while other matches kept us busy. Pure DB, no upstream call.
      const reaped = await this.scores.finalizeStaleLiveMatches();
      if (reaped) this.log.warn(`reaped ${reaped} stale live match(es)`);

      // Step 1: Decide whether a match is in play or imminent. `hasActiveMatches`
      // covers anything LIVE/HT and anything whose kickoff has passed (≤3.5h) but
      // hasn't finished — so we can't idle mid-match or through a late kickoff.
      // We ALSO watch from ~1h before the next kickoff (lineups + catch the start).
      const active = await this.scores.hasActiveMatches();
      const next = await this.cache.getNextKickoff();
      const untilNext = next ? next.getTime() - Date.now() : Infinity;
      const watching = active || untilNext <= this.preWindowMs;

      if (!watching) {
        // No match near. This is the big quota win: instead of waking every few
        // minutes and hitting the schedule endpoint, sleep until ~1h before the
        // next kickoff and refresh the full schedule only every refreshEveryMs
        // (settles finished scores + updates the next kickoff). No per-tick calls.
        if (Date.now() - this.lastScheduleRefresh >= this.refreshEveryMs) {
          await this.refreshSchedule();
          this.lastScheduleRefresh = Date.now();
        }
        nextDelay = next
          ? Math.min(this.maxIdleMs, Math.max(this.watchMs, untilNext - this.preWindowMs))
          : this.maxIdleMs;
        this.log.log(
          `idle: nextKickoff=${next?.toISOString() ?? 'unknown'} sleep=${Math.round(nextDelay / 1000)}s`,
        );
        return;
      }

      // Step 2: Watch/live. ONE upstream call — `live=all` — returns every match
      // in play globally (incl. extra time & shootouts, which stay live until api
      // ends them). Filter to the leagues we track.
      const trackedIds = new Set(this.leagues.map((l) => l.id));
      const allLive = await this.api.liveFixtures();
      const liveMatches = allLive.filter((f) => trackedIds.has(f.league.id));

      if (liveMatches.length) {
        await this.cache.markLive();
        // Prime events/lineups/stats for the live matches in ONE batched call so
        // app opens hit the cache. Best-effort — never blocks the tick.
        await this.cache
          .primeLiveFixtures(liveMatches.map((f) => f.fixture.id))
          .catch((e) => this.log.warn(`prime failed: ${(e as Error).message}`));
      }

      const { changed, live, finishedFixtureIds } = await this.scores.ingestSnapshot(liveMatches);
      for (const id of finishedFixtureIds ?? []) {
        await this.cache.freezeFixture(id);
      }

      // Refresh the full schedule (settles results, recomputes standings/bracket
      // + the next kickoff) on a full-time transition, or — while we're watching
      // but nothing is live yet (pre-kickoff / a postponement) — at most every
      // refreshEveryMs. This is the only place per-league schedule calls happen.
      const finished = (finishedFixtureIds?.length ?? 0) > 0;
      if (finished || (!liveMatches.length && Date.now() - this.lastScheduleRefresh >= this.refreshEveryMs)) {
        await this.refreshSchedule();
        this.lastScheduleRefresh = Date.now();
      }

      nextDelay = liveMatches.length > 0 ? this.liveMs : this.watchMs;

      const quota = this.api.getQuota();
      this.log.log(
        `live: live=${live} changed=${changed} ` +
          `quota=${quota.minuteRemaining}/min ${quota.dailyRemaining}/day sleep=${Math.round(nextDelay / 1000)}s (${Date.now() - start}ms)`,
      );
    } catch (err) {
      this.log.error(`poll tick failed: ${(err as Error).message}`);
      nextDelay = Math.min(this.maxIdleMs, 60_000);
    } finally {
      this.timer = setTimeout(() => this.tick().catch(() => {}), nextDelay);
    }
  }

  /**
   * Pull the full schedule for every tracked league (parallel), then:
   *  - SETTLE every fixture against it (silent — no goal pushes): corrects a
   *    match the live loop lost track of (e.g. a stale-reaped one frozen mid-game
   *    at the wrong score, or one stuck SCHEDULED because we never caught it live).
   *    The full schedule carries the real final status/score for every match.
   *  - recompute standings + knockout bracket if anything settled to full-time.
   *  - persist the next kickoff.
   */
  private async refreshSchedule(): Promise<void> {
    try {
      const lists = await Promise.all(
        this.leagues.map((l) =>
          this.api
            .listMatches({ league: l.id, season: l.season })
            .catch((e) => {
              this.log.warn(`schedule fetch failed league=${l.id}: ${(e as Error).message}`);
              return [] as ApiFixture[];
            }),
        ),
      );
      const all = lists.flat();

      const { changed, finishedFixtureIds } = await this.scores.ingestSnapshot(all, { silent: true });
      for (const id of finishedFixtureIds ?? []) {
        await this.cache.freezeFixture(id);
      }
      if ((finishedFixtureIds?.length ?? 0) > 0) {
        await this.scores
          .recomputeStandings()
          .then(() => this.scores.reconcileKnockout())
          .catch((e) => this.log.warn(`settle standings/knockout failed: ${(e as Error).message}`));
      }
      if (changed) this.log.log(`schedule settle: corrected ${changed} fixture(s)`);

      await this.recomputeNextKickoff(all);
    } catch (e) {
      this.log.warn(`schedule refresh failed: ${(e as Error).message}`);
    }
  }

  private async recomputeNextKickoff(fixtures: Array<{ fixture: { date: string; status: { short: string } } }>): Promise<void> {
    const now = Date.now();
    const upcoming = fixtures
      .filter((f) => ['NS', 'TBD', 'PST'].includes(f.fixture.status.short))
      .map((f) => new Date(f.fixture.date))
      .filter((d) => d.getTime() > now - 4 * 60 * 60_000)
      .sort((a, b) => a.getTime() - b.getTime());
    await this.cache.setNextKickoff(upcoming[0] ?? null);
  }

  onApplicationShutdown() {
    this.stopped = true;
    if (this.timer) clearTimeout(this.timer);
  }
}
