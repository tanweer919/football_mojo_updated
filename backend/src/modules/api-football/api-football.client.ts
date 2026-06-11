import { HttpException, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosInstance, AxiosResponse } from 'axios';
import axiosRetry from 'axios-retry';
import { resolveApiFootballConfig } from './api-football.config';

/**
 * api-football v3 client. All responses follow the same envelope:
 *   { get, parameters, errors, results, paging, response: [...] }
 *
 * Free tier: 100 req/day. Pro: 7500/day. Mega: 75k/day. Rate-limit headers:
 *   x-ratelimit-requests-remaining    (per day)
 *   X-RateLimit-Remaining             (per minute)
 *
 * We expose the headers via [getQuota] so workers can back off intelligently.
 */
export interface ApiFootballEnvelope<T> {
  get: string;
  parameters: Record<string, string>;
  errors: unknown[] | { rateLimit?: string; token?: string; requests?: string };
  results: number;
  paging: { current: number; total: number };
  response: T[];
}

export interface ApiFixturePlayerStat {
  player: { id: number; name: string; photo?: string | null };
  statistics: Array<{
    games: { minutes: number | null; number: number | null; position: 'G' | 'D' | 'M' | 'F' | null; rating: string | null; captain: boolean; substitute: boolean };
    offsides: number | null;
    shots: { total: number | null; on: number | null };
    goals: { total: number | null; conceded: number | null; assists: number | null; saves: number | null };
    passes: { total: number | null; key: number | null; accuracy: string | null };
    tackles: { total: number | null; blocks: number | null; interceptions: number | null };
    duels: { total: number | null; won: number | null };
    dribbles: { attempts: number | null; success: number | null; past: number | null };
    fouls: { drawn: number | null; committed: number | null };
    cards: { yellow: number; red: number };
    penalty: { won: number | null; commited: number | null; scored: number; missed: number; saved: number };
  }>;
}

export interface ApiFixturePlayersTeam {
  team: { id: number; name: string; logo: string };
  players: ApiFixturePlayerStat[];
}

export interface ApiFixture {
  fixture: {
    id: number;
    date: string;
    timestamp: number;
    venue: { id: number | null; name: string | null; city: string | null };
    status: { long: string; short: string; elapsed: number | null; extra: number | null };
  };
  league: { id: number; name: string; season: number; round: string };
  teams: { home: { id: number; name: string; logo: string }; away: { id: number; name: string; logo: string } };
  goals: { home: number | null; away: number | null };
  score: {
    halftime: { home: number | null; away: number | null };
    fulltime: { home: number | null; away: number | null };
    extratime: { home: number | null; away: number | null };
    penalty:  { home: number | null; away: number | null };
  };
}

export interface ApiSquadPlayer { id: number; name: string; age: number | null; number: number | null; position: string; photo: string }
export interface ApiSquadResponse { team: { id: number; name: string; logo: string }; players: ApiSquadPlayer[] }

export interface ApiFixtureEvent {
  time: { elapsed: number; extra: number | null };
  team: { id: number; name: string; logo: string };
  player: { id: number | null; name: string | null };
  assist: { id: number | null; name: string | null };
  type: 'Goal' | 'Card' | 'subst' | 'Var';
  detail: string;
  comments: string | null;
}

export interface ApiLineup {
  team: { id: number; name: string };
  formation: string;
  startXI: Array<{ player: { id: number; name: string; number: number; pos: 'G' | 'D' | 'M' | 'F'; grid: string | null } }>;
  substitutes: Array<{ player: { id: number; name: string; number: number; pos: 'G' | 'D' | 'M' | 'F'; grid: null } }>;
  coach: { id: number; name: string; photo: string };
}

export interface ApiInjury {
  player: { id: number; name: string; photo: string; type: string; reason: string };
  team:   { id: number; name: string; logo: string };
  fixture:{ id: number; timezone: string; date: string; timestamp: number };
  league: { id: number; season: number; name: string };
}

@Injectable()
export class ApiFootballClient {
  private readonly log = new Logger(ApiFootballClient.name);
  private readonly http: AxiosInstance;
  private lastDailyRemaining = Number.POSITIVE_INFINITY;
  private lastMinuteRemaining = Number.POSITIVE_INFINITY;

  constructor(cfg: ConfigService) {
    const { baseURL, headers } = resolveApiFootballConfig({
      // ConfigService falls back to process.env, but build the env-like view
      // explicitly so the config resolver works the same in seed/CLI contexts.
      API_FOOTBALL_KEY:      cfg.get<string>('API_FOOTBALL_KEY'),
      API_FOOTBALL_BASE:     cfg.get<string>('API_FOOTBALL_BASE'),
      API_FOOTBALL_PROVIDER: cfg.get<string>('API_FOOTBALL_PROVIDER'),
    } as NodeJS.ProcessEnv);
    this.http = axios.create({ baseURL, timeout: 15_000, headers });
    axiosRetry(this.http, {
      retries: 3,
      retryDelay: axiosRetry.exponentialDelay,
      retryCondition: (err) =>
        axiosRetry.isNetworkOrIdempotentRequestError(err) ||
        [429, 500, 502, 503, 504].includes(err.response?.status ?? 0),
    });

    this.http.interceptors.response.use((r: AxiosResponse) => {
      const daily   = Number(r.headers['x-ratelimit-requests-remaining']);
      const perMin  = Number(r.headers['x-ratelimit-remaining']);
      if (!Number.isNaN(daily))  this.lastDailyRemaining  = daily;
      if (!Number.isNaN(perMin)) this.lastMinuteRemaining = perMin;
      return r;
    });
  }

  getQuota() {
    return { dailyRemaining: this.lastDailyRemaining, minuteRemaining: this.lastMinuteRemaining };
  }

  private async get<T>(path: string, params: Record<string, string | number | undefined>): Promise<T[]> {
    const cleaned: Record<string, string | number> = {};
    for (const [k, v] of Object.entries(params)) if (v !== undefined && v !== null) cleaned[k] = v;
    const { data } = await this.http.get<ApiFootballEnvelope<T>>(path, { params: cleaned });
    if (Array.isArray(data.errors) ? data.errors.length : Object.keys(data.errors).length) {
      this.log.error(`api-football ${path} errors: ${JSON.stringify(data.errors)}`);
      throw new HttpException('upstream_errors', 502);
    }
    return data.response;
  }

  // High-level endpoints — typed wrappers.

  fixturesByLeagueSeason(leagueId: number, season: number) {
    return this.get<ApiFixture>('/fixtures', { league: leagueId, season });
  }

  /**
   * Currently-live fixtures. `live` is an upstream filter that returns only
   * matches in 1H/HT/2H/ET/BT/P. Pass a leagueId to scope to one competition.
   */
  liveFixtures(leagueId?: number) {
    return this.get<ApiFixture>('/fixtures', leagueId
      ? { live: 'all', league: leagueId }
      : { live: 'all' });
  }

  /**
   * Generic fixture list. Used by the realtime poller for date-filtered idle
   * refreshes (catches SCHEDULED → LIVE transitions on kickoff).
   */
  listMatches(params: { league?: number; season?: number; date?: string; status?: string; team?: number; round?: string }) {
    return this.get<ApiFixture>('/fixtures', params);
  }

  fixtureById(id: number) {
    return this.get<ApiFixture>('/fixtures', { id }).then((rows) => rows[0]);
  }

  teamsByLeagueSeason(leagueId: number, season: number) {
    return this.get<{ team: { id: number; name: string; code: string | null; logo: string; country: string }; venue: unknown }>(
      '/teams',
      { league: leagueId, season },
    );
  }

  squad(teamId: number) {
    return this.get<ApiSquadResponse>('/players/squads', { team: teamId });
  }

  // The fantasy scoring engine consumes this directly. One call per fixture, ~once/min while live.
  fixturePlayers(fixtureId: number) {
    return this.get<ApiFixturePlayersTeam>('/fixtures/players', { fixture: fixtureId });
  }

  fixtureEvents(fixtureId: number) {
    return this.get<ApiFixtureEvent>('/fixtures/events', { fixture: fixtureId });
  }

  fixtureLineups(fixtureId: number) {
    return this.get<ApiLineup>('/fixtures/lineups', { fixture: fixtureId });
  }

  fixtureStatistics(fixtureId: number) {
    return this.get<{ team: { id: number }; statistics: Array<{ type: string; value: number | string | null }> }>(
      '/fixtures/statistics',
      { fixture: fixtureId },
    );
  }

  injuries(leagueId: number, season: number) {
    return this.get<ApiInjury>('/injuries', { league: leagueId, season });
  }

  topScorers(leagueId: number, season: number) {
    return this.get<{ player: { id: number; name: string; photo: string }; statistics: unknown[] }>(
      '/players/topscorers',
      { league: leagueId, season },
    );
  }

  topAssists(leagueId: number, season: number) {
    return this.get<{ player: { id: number; name: string; photo: string }; statistics: unknown[] }>(
      '/players/topassists',
      { league: leagueId, season },
    );
  }

  prediction(fixtureId: number) {
    return this.get<{
      predictions: { winner: { id: number; name: string; comment: string }; advice: string; percent: { home: string; draw: string; away: string } };
      comparison: Record<string, { home: string; away: string }>;
      teams: { home: unknown; away: unknown };
    }>('/predictions', { fixture: fixtureId });
  }

  headToHead(team1: number, team2: number, last = 10) {
    return this.get<ApiFixture>('/fixtures/headtohead', { h2h: `${team1}-${team2}`, last });
  }

  standings(leagueId: number, season: number) {
    return this.get<{ league: { standings: unknown[][] } }>('/standings', { league: leagueId, season });
  }

  playerProfile(playerId: number) {
    return this.get<{ player: unknown }>('/players/profiles', { player: playerId });
  }

  playerSeasonStats(playerId: number, season: number) {
    return this.get<{ player: unknown; statistics: unknown[] }>('/players', { id: playerId, season });
  }

  transfers(playerId: number) {
    return this.get<{ player: { id: number; name: string }; transfers: unknown[] }>('/transfers', { player: playerId });
  }

  trophies(playerId: number) {
    return this.get<{ league: string; country: string; season: string; place: string }>('/trophies', { player: playerId });
  }

  sidelined(playerId: number) {
    return this.get<{ type: string; start: string; end: string }>('/sidelined', { player: playerId });
  }
}
