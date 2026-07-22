import { CacheInterceptor, CacheTTL } from '@nestjs/cache-manager';
import { Controller, Get, Param, Query, UseInterceptors } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApiFootballCacheService } from '../api-football/api-football-cache.service';
import { ApiFootballClient } from '../api-football/api-football.client';
import { LEAGUES } from '../competitions/leagues.config';

/**
 * "Extras" surfaced from api-football. Two-tier caching:
 *   - per-method Redis cache via ApiFootballCacheService (dedupes upstream)
 *   - per-route HTTP cache via CacheInterceptor (dedupes serialization)
 *
 * For high-frequency endpoints (lineup, stats, events) we go through the
 * cache service so live windows don't burn the rate limit.
 */
@Controller({ path: 'insights', version: '1' })
@UseInterceptors(CacheInterceptor)
export class InsightsController {
  private readonly leagueId: number;
  private readonly season: number;

  constructor(
    cfg: ConfigService,
    private readonly cache: ApiFootballCacheService,
    private readonly api: ApiFootballClient,
  ) {
    this.leagueId = +(cfg.get<string>('API_FOOTBALL_WC_LEAGUE_ID') ?? '1');
    this.season = +(cfg.get<string>('API_FOOTBALL_WC_SEASON') ?? '2026');
  }

  /**
   * Resolve a competition id (e.g. "PL_2025") to its api-football league id +
   * season via the LEAGUES config. Drives the league/year selector — standings
   * and scorers switch to whatever competition the client asks for. Falls back
   * to the configured default when the id is missing/unknown.
   */
  private resolve(competitionId?: string): { leagueId: number; season: number } {
    if (competitionId) {
      const l = LEAGUES.find((x) => x.code === competitionId);
      if (l) return { leagueId: l.id, season: l.season };
    }
    return { leagueId: this.leagueId, season: this.season };
  }

  @Get('injuries')
  @CacheTTL(900_000)
  injuries() {
    return this.cache.injuries(this.leagueId, this.season);
  }

  @Get('top-scorers')
  @CacheTTL(900_000)
  topScorers(@Query('competitionId') competitionId?: string) {
    const { leagueId, season } = this.resolve(competitionId);
    return this.cache.topScorers(leagueId, season);
  }

  @Get('top-assists')
  @CacheTTL(900_000)
  topAssists(@Query('competitionId') competitionId?: string) {
    const { leagueId, season } = this.resolve(competitionId);
    return this.cache.topAssists(leagueId, season);
  }

  @Get('predictions/:fixtureId')
  @CacheTTL(1_800_000)
  prediction(@Param('fixtureId') fixtureId: string) {
    return this.cache.prediction(+fixtureId);
  }

  @Get('h2h')
  @CacheTTL(86_400_000)
  headToHead(
    @Query('team1') team1: string,
    @Query('team2') team2: string,
    @Query('last') last?: string,
  ) {
    return this.cache.headToHead(+team1, +team2, last ? +last : 10);
  }

  @Get('lineup/:fixtureId')
  @CacheTTL(60_000)
  lineup(@Param('fixtureId') fixtureId: string) {
    return this.cache.fixtureLineups(+fixtureId);
  }

  @Get('match-statistics/:fixtureId')
  @CacheTTL(30_000)
  stats(@Param('fixtureId') fixtureId: string) {
    return this.cache.fixtureStatistics(+fixtureId);
  }

  @Get('match-events/:fixtureId')
  @CacheTTL(20_000)
  events(@Param('fixtureId') fixtureId: string) {
    return this.cache.fixtureEvents(+fixtureId);
  }

  @Get('player/:id')
  @CacheTTL(900_000)
  async player(@Param('id') id: string) {
    const playerId = +id;
    const [profile, season, transfers, trophies, sidelined] = await Promise.allSettled([
      this.cache.playerProfile(playerId),
      this.cache.playerSeasonStats(playerId, this.season),
      this.api.transfers(playerId),
      this.api.trophies(playerId),
      this.api.sidelined(playerId),
    ]);
    return {
      profile:   profile.status   === 'fulfilled' ? profile.value[0]   ?? null : null,
      season:    season.status    === 'fulfilled' ? season.value[0]    ?? null : null,
      transfers: transfers.status === 'fulfilled' ? transfers.value[0] ?? null : null,
      trophies:  trophies.status  === 'fulfilled' ? trophies.value             : [],
      sidelined: sidelined.status === 'fulfilled' ? sidelined.value            : [],
    };
  }

  @Get('standings')
  @CacheTTL(900_000)
  standings(@Query('competitionId') competitionId?: string) {
    const { leagueId, season } = this.resolve(competitionId);
    return this.cache.standings(leagueId, season);
  }

  /** Quota visibility for ops dashboards. */
  @Get('quota')
  quota() {
    return this.cache.getQuota();
  }
}
