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
  private readonly liveMs: number;
  private readonly idleMs: number;
  private readonly leagues: LeagueConfig[];
  private timer: NodeJS.Timeout | null = null;
  private stopped = false;

  constructor(
    cfg: ConfigService,
    private readonly api: ApiFootballClient,
    private readonly cache: ApiFootballCacheService,
    private readonly scores: ScoresService,
  ) {
    this.liveMs = +(cfg.get('POLL_INTERVAL_LIVE_MS') ?? 15_000);
    this.idleMs = +(cfg.get('POLL_INTERVAL_IDLE_MS') ?? 600_000);
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
    this.tick().catch((e) => this.log.error('initial tick failed', e));
  }

  async tick() {
    if (this.stopped) return;
    const start = Date.now();
    let nextDelay = this.idleMs;

    try {
      // Step 1: Are we even in a live window across ANY tracked league? If
      // not, skip the upstream call entirely and reschedule. We OR the
      // kickoff-proximity window with a DB check for matches actually in play,
      // so the poller can't idle mid-match (and self-heals a frozen one).
      const inWindow =
        (await this.cache.isLiveWindow(15)) || (await this.scores.hasActiveMatches());
      if (!inWindow) {
        const next = await this.cache.getNextKickoff();
        if (next) {
          const untilKickoff = next.getTime() - Date.now() - 60_000;
          nextDelay = Math.max(this.liveMs, Math.min(this.idleMs, untilKickoff));
        }
        // Opportunistic schedule refresh — once per quiet tick at most.
        if (Date.now() - start < 1000) {
          await this.refreshSchedule();
        }
        this.log.log(
          `idle tick: nextKickoff=${next?.toISOString() ?? 'unknown'} nextDelay=${nextDelay}ms`,
        );
        return;
      }

      // Step 2: Live tick. ONE upstream call returns every live match
      // globally; filter to the leagues we track.
      const trackedIds = new Set(this.leagues.map((l) => l.id));
      const allLive = await this.api.liveFixtures();
      const liveMatches = allLive.filter((f) => trackedIds.has(f.league.id));

      let scanned: ApiFixture[] = liveMatches;
      const wasLive = liveMatches.length > 0;
      if (wasLive) await this.cache.markLive();

      // Nothing live anywhere → idle refresh per league (parallel) so
      // SCHEDULED→LIVE transitions get caught.
      if (!liveMatches.length) {
        const today = new Date().toISOString().slice(0, 10);
        const perLeague = await Promise.all(
          this.leagues.map((l) =>
            this.api
              .listMatches({ league: l.id, season: l.season, date: today })
              .catch((e) => {
                this.log.warn(`idle scan failed for league=${l.id}: ${(e as Error).message}`);
                return [] as ApiFixture[];
              }),
          ),
        );
        scanned = perLeague.flat();
      }

      const { changed, live, finishedFixtureIds } =
        await this.scores.ingestSnapshot(scanned);

      for (const id of finishedFixtureIds ?? []) {
        await this.cache.freezeFixture(id);
      }

      await this.recomputeNextKickoff(scanned);

      nextDelay = live > 0 ? this.liveMs : this.idleMs;

      const quota = this.api.getQuota();
      this.log.log(
        `live tick: scanned=${scanned.length} live=${live} changed=${changed} ` +
          `quota=${quota.minuteRemaining}/min ${quota.dailyRemaining}/day nextDelay=${nextDelay}ms (${Date.now() - start}ms)`,
      );
    } catch (err) {
      this.log.error(`poll tick failed: ${(err as Error).message}`);
      nextDelay = Math.min(this.idleMs, 60_000);
    } finally {
      this.timer = setTimeout(() => this.tick().catch(() => {}), nextDelay);
    }
  }

  /** Pull the schedule for every tracked league (parallel) and persist next kickoff. */
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
      await this.recomputeNextKickoff(lists.flat());
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
