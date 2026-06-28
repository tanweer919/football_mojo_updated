import { Inject, Injectable, Logger } from '@nestjs/common';
import { Match, MatchStatus } from '@prisma/client';
import Redis from 'ioredis';
import { PrismaService } from '../../common/prisma.service';
import { REDIS_PUB } from '../../common/redis.module';
import { ApiFixture } from '../api-football/api-football.client';
import { mapApiFootballStatus } from '../api-football/status-map';
import { competitionIdForApi } from '../competitions/leagues.config';
import { CHANNELS, MatchUpdatePayload } from './scores.events';
import { fixturePairKey, canonicalTeamName, normalizeTeamName } from './wc-team-aliases';

const WC_COMPETITION_ID = 'WC2026';

/**
 * Authoritative Round-of-32 matchups, keyed by the seed fixture id. Each seed
 * R32 row is uniquely identified by its stadium + date, and that maps 1:1 to the
 * official bracket — so the real teams can be filled in without guessing the
 * FIFA positional / third-place allocation table. Home/away follow the official
 * listing; the api fixture (with the live score) supersedes these once published.
 */
const WC2026_R32_TEMPLATE: Record<string, [string, string]> = {
  'WC2026-R32-M73': ['South Africa', 'Canada'],
  'WC2026-R32-M74': ['Germany', 'Paraguay'],
  'WC2026-R32-M75': ['Netherlands', 'Morocco'],
  'WC2026-R32-M76': ['Brazil', 'Japan'],
  'WC2026-R32-M77': ['France', 'Sweden'],
  'WC2026-R32-M78': ['Ivory Coast', 'Norway'],
  'WC2026-R32-M79': ['Mexico', 'Ecuador'],
  'WC2026-R32-M80': ['England', 'DR Congo'],
  'WC2026-R32-M81': ['United States', 'Bosnia and Herzegovina'],
  'WC2026-R32-M82': ['Belgium', 'Senegal'],
  'WC2026-R32-M83': ['Portugal', 'Croatia'],
  'WC2026-R32-M84': ['Spain', 'Austria'],
  'WC2026-R32-M85': ['Switzerland', 'Algeria'],
  'WC2026-R32-M86': ['Argentina', 'Cape Verde'],
  'WC2026-R32-M87': ['Colombia', 'Ghana'],
  'WC2026-R32-M88': ['Australia', 'Egypt'],
};

/**
 * Knockout feed tree (match number → its two feeders), parsed from the seed
 * placeholders. "W74" = winner of match 74; "L101" = loser of match 101 (the
 * bronze final feeds off the semis). Combined with the R32 template, this lets
 * every later round (R16 → final) resolve automatically as results come in — no
 * manual data needed beyond the Round of 32.
 */
const WC2026_KO_FEED: Record<number, [string, string]> = {
  89: ['W74', 'W77'], 90: ['W73', 'W75'], 91: ['W76', 'W78'], 92: ['W79', 'W80'],
  93: ['W83', 'W84'], 94: ['W81', 'W82'], 95: ['W86', 'W88'], 96: ['W85', 'W87'],
  97: ['W89', 'W90'], 98: ['W93', 'W94'], 99: ['W91', 'W92'], 100: ['W95', 'W96'],
  101: ['W97', 'W98'], 102: ['W99', 'W100'], 103: ['L101', 'L102'], 104: ['W101', 'W102'],
};

/** Seed fixture id for a knockout match number (matches the WC seed's id scheme). */
function wcSeedId(n: number): string {
  if (n <= 88) return `WC2026-R32-M${n}`;
  if (n <= 96) return `WC2026-R16-M${n}`;
  if (n <= 100) return `WC2026-QF-M${n}`;
  if (n <= 102) return `WC2026-SF-M${n}`;
  if (n === 103) return `WC2026-3RD-M${n}`;
  return `WC2026-FINAL-M${n}`;
}

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
  async ingestSnapshot(
    upstream: ApiFixture[],
    opts: { silent?: boolean } = {},
  ): Promise<{ changed: number; live: number; finishedFixtureIds: number[] }> {
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
      // api-football occasionally sends `extra` (stoppage) with a null/0
      // `elapsed`, which downstream renders as the nonsensical "0+3". Only keep
      // stoppage when there's a real base minute to add it to.
      const minuteExtra   = (minute && minute > 0) ? u.fixture.status.extra : null;

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
      // even if /fixtures/events hasn't caught up yet. Skipped in `silent` settle
      // passes (re-ingesting the full schedule) so correcting an old/stale score
      // never fires push notifications for a match that finished hours ago.
      if (!opts.silent) {
        if (homeScore > existing.homeScore) {
          await this.recordSynthEvent(id, minute ?? 0, 'GOAL', existing.homeTeamId);
        }
        if (awayScore > existing.awayScore) {
          await this.recordSynthEvent(id, minute ?? 0, 'GOAL', existing.awayTeamId);
        }
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
   * Self-heal matches frozen in a live state. api-football drops a fixture from
   * `live=all` the instant it ends; if other matches keep the poller in its live
   * cadence, the ended one is never re-scanned and its row stays LIVE at the last
   * snapshot — e.g. stuck at 90+10 indefinitely. That also keeps
   * `hasActiveMatches()` true, so the poller burns a `live=all` call every tick
   * forever on a phantom match.
   *
   * No match runs longer than ~3.5h end-to-end (90 + stoppage, or 120 of extra
   * time + breaks + a shootout), so any fixture still LIVE/HALF_TIME whose
   * kickoff was earlier than that is certainly over. Close it out at its last
   * known score/penalties and publish so clients flip to full-time. Pure DB —
   * zero api-football cost. Returns how many it reaped.
   */
  async finalizeStaleLiveMatches(): Promise<number> {
    const cutoff = new Date(Date.now() - 3.5 * 60 * 60_000);
    const stale = await this.prisma.match.findMany({
      where: {
        status: { in: ['LIVE', 'HALF_TIME'] },
        kickoffAt: { lt: cutoff },
      },
    });
    for (const m of stale) {
      const updated = await this.prisma.match.update({
        where: { id: m.id },
        data: { status: MatchStatus.FINISHED },
      });
      await this.publishUpdate(updated);
      this.log.warn(
        `finalized stale live match ${m.id} ${m.homeScore}-${m.awayScore} ` +
          `(kickoff ${m.kickoffAt.toISOString()}) — it had dropped from live=all`,
      );
    }
    return stale.length;
  }

  /**
   * Recompute every group table from FINISHED match results and write it into
   * `GroupStanding`. We own this — the seed creates the rows at 0 and nothing
   * else ever updates them, so the World Cup screen (`/competitions/:id/groups`)
   * and bracket scoring (which reads `standings.played`/`position`) were stuck
   * at zero. Deriving from our own results is exact and costs zero api-football
   * quota. Two nations only ever meet in the group stage (the bracket keeps
   * same-group teams apart), so "both teams in the same group + FINISHED" is a
   * safe group-match test without depending on `Match.stage`.
   *
   * Ranking: points, then goal difference, then goals for (the standard primary
   * order; full FIFA head-to-head tie-breaks are out of scope).
   */
  async recomputeStandings(): Promise<void> {
    const groups = await this.prisma.group.findMany({
      include: { standings: { select: { teamId: true } } },
    });
    if (groups.length === 0) return;

    const groupOfTeam = new Map<string, string>();
    for (const g of groups) {
      for (const s of g.standings) groupOfTeam.set(s.teamId, g.id);
    }

    type Tally = { played: number; won: number; drawn: number; lost: number; gf: number; ga: number; pts: number };
    const blank = (): Tally => ({ played: 0, won: 0, drawn: 0, lost: 0, gf: 0, ga: 0, pts: 0 });
    const acc = new Map<string, Map<string, Tally>>();
    for (const g of groups) {
      const m = new Map<string, Tally>();
      for (const s of g.standings) m.set(s.teamId, blank());
      acc.set(g.id, m);
    }

    const matches = await this.prisma.match.findMany({
      where: { status: 'FINISHED' },
      select: { homeTeamId: true, awayTeamId: true, homeScore: true, awayScore: true },
    });
    for (const mt of matches) {
      const gid = groupOfTeam.get(mt.homeTeamId);
      if (!gid || gid !== groupOfTeam.get(mt.awayTeamId)) continue; // not a group match
      const table = acc.get(gid)!;
      const h = table.get(mt.homeTeamId)!;
      const a = table.get(mt.awayTeamId)!;
      h.played++; a.played++;
      h.gf += mt.homeScore; h.ga += mt.awayScore;
      a.gf += mt.awayScore; a.ga += mt.homeScore;
      if (mt.homeScore > mt.awayScore) { h.won++; h.pts += 3; a.lost++; }
      else if (mt.homeScore < mt.awayScore) { a.won++; a.pts += 3; h.lost++; }
      else { h.drawn++; a.drawn++; h.pts++; a.pts++; }
    }

    for (const g of groups) {
      const rows = [...acc.get(g.id)!.entries()]
        .map(([teamId, t]) => ({ teamId, ...t, gd: t.gf - t.ga }))
        .sort((x, y) => y.pts - x.pts || y.gd - x.gd || y.gf - x.gf || x.teamId.localeCompare(y.teamId));
      let position = 1;
      for (const r of rows) {
        await this.prisma.groupStanding.updateMany({
          where: { groupId: g.id, teamId: r.teamId },
          data: {
            played: r.played, won: r.won, drawn: r.drawn, lost: r.lost,
            goalsFor: r.gf, goalsAg: r.ga, points: r.pts, position,
          },
        });
        position++;
      }
    }
  }

  /**
   * Resolve knockout-bracket placeholders into real teams, and drop duplicates.
   *
   * The WC seed creates the full knockout tree up front with PLACEHOLDER teams
   * named by bracket slot ("A1", "B2", … = group winner/runner-up). api-football
   * separately publishes the real knockout fixtures (numeric ids) as positions
   * lock — so the bracket shows cryptic "A2/B1" placeholders AND duplicates.
   *
   * Pipeline:
   *   1. Apply the authoritative R32 template (seedId → real teams) via an
   *      alias-aware nation→team lookup — resolves all 16 R32 ties including the
   *      eight third-place qualifiers, the moment the nations exist.
   *   2. Propagate winners/losers through the feed tree (WC2026_KO_FEED): once a
   *      result is in, fill the next round's "W74"/"L101" placeholders. Iterating
   *      in match-number order resolves R16 → final in one pass — no manual data
   *      beyond the R32 template.
   *   3. Drop a seed row once a real api fixture covers the same tie (alias-aware
   *      nation pair) — keeping the api row's live schedule/score, no duplicates.
   */
  async reconcileKnockout(): Promise<void> {
    // Canonical nation name → the real team row used in results.
    const groups = await this.prisma.group.findMany({
      include: { standings: { select: { team: { select: { id: true, name: true } } } } },
    });
    const nameToId = new Map<string, string>();
    for (const g of groups)
      for (const r of g.standings) nameToId.set(normalizeTeamName(canonicalTeamName(r.team.name)), r.team.id);
    const idFor = (canonName: string) => nameToId.get(normalizeTeamName(canonName));

    // 1) R32 template → resolved canonical-name pair per match number.
    const teamsOf = new Map<number, [string, string]>();
    for (const [seedId, [home, away]] of Object.entries(WC2026_R32_TEMPLATE)) {
      teamsOf.set(+seedId.split('-M')[1], [canonicalTeamName(home), canonicalTeamName(away)]);
    }

    // Index every finished knockout result by alias-aware pair → winner/loser.
    const allKo = await this.prisma.match.findMany({
      where: { stage: { not: null } },
      select: {
        id: true, stage: true, status: true,
        homeScore: true, awayScore: true, homePenalties: true, awayPenalties: true,
        homeTeam: { select: { name: true } }, awayTeam: { select: { name: true } },
      },
    });
    const ko = allKo.filter((m) => m.stage && !/group/i.test(m.stage));
    const resultByPair = new Map<string, { winner: string; loser: string }>();
    for (const m of ko) {
      if (m.status !== MatchStatus.FINISHED) continue;
      const hn = canonicalTeamName(m.homeTeam?.name ?? '');
      const an = canonicalTeamName(m.awayTeam?.name ?? '');
      const hScore = m.homeScore ?? 0, aScore = m.awayScore ?? 0;
      let winner = hn, loser = an;
      if (hScore < aScore) { winner = an; loser = hn; }
      else if (hScore === aScore) {
        const hp = m.homePenalties ?? 0, ap = m.awayPenalties ?? 0;
        if (hp === ap) continue; // not actually decided
        if (hp < ap) { winner = an; loser = hn; }
      }
      resultByPair.set(fixturePairKey(hn, an), { winner, loser });
    }

    // 2) Propagate winners/losers through the tree, in match-number order so each
    //    later round sees its feeders already resolved.
    for (let n = 89; n <= 104; n++) {
      const feed = WC2026_KO_FEED[n];
      if (!feed) continue;
      const resolve = (ref: string): string | undefined => {
        const pair = teamsOf.get(+ref.slice(1));
        if (!pair) return undefined;
        const r = resultByPair.get(fixturePairKey(pair[0], pair[1]));
        if (!r) return undefined;
        return ref[0] === 'W' ? r.winner : r.loser;
      };
      const home = resolve(feed[0]);
      const away = resolve(feed[1]);
      if (home && away) teamsOf.set(n, [home, away]);
    }

    // Write resolved teams onto the seed rows (R32 + any propagated later rounds).
    for (const [n, [home, away]] of teamsOf) {
      const hid = idFor(home), aid = idFor(away);
      if (!hid || !aid) continue; // nation not in the DB yet — retry next pass
      const id = wcSeedId(n);
      const ex = await this.prisma.match.findUnique({ where: { id }, select: { homeTeamId: true, awayTeamId: true } });
      if (!ex || (ex.homeTeamId === hid && ex.awayTeamId === aid)) continue; // gone or unchanged
      await this.prisma.match
        .update({ where: { id }, data: { homeTeamId: hid, awayTeamId: aid } })
        .catch((e) => this.log.warn(`knockout resolve failed ${id}: ${(e as Error).message}`));
    }

    // 3) Drop seed rows superseded by a real api fixture for the same tie. A tie
    //    is unique across the knockout, so the alias-aware nation pair is enough
    //    (and survives api/seed stage-string differences). Seed pairs come from
    //    `teamsOf` (post-resolution); api pairs from their own real names.
    const apiPairs = new Set<string>();
    for (const m of ko) if (!m.id.startsWith('WC2026-')) apiPairs.add(fixturePairKey(m.homeTeam?.name ?? '', m.awayTeam?.name ?? ''));
    const drop: string[] = [];
    for (const [n, [home, away]] of teamsOf) {
      if (apiPairs.has(fixturePairKey(home, away))) drop.push(wcSeedId(n));
    }
    if (drop.length) {
      const { count } = await this.prisma.match.deleteMany({ where: { id: { in: drop } } });
      if (count) this.log.log(`knockout dedup: dropped ${count} superseded seed placeholder(s)`);
    }
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

  /// All fixtures in an inclusive [from, to] date range, in ONE query — so the
  /// home/My-Team/matches screens fetch a multi-day window in a single request
  /// instead of one call per day.
  async getFixturesRange(from: string, to: string) {
    const key = `fixtures:range:${from}:${to}`;
    const cached = await this.pub.get(key);
    if (cached) return JSON.parse(cached);
    const start = new Date(`${from}T00:00:00Z`);
    const end = new Date(`${to}T23:59:59Z`);
    const rows = await this.prisma.match.findMany({
      where: { kickoffAt: { gte: start, lte: end } },
      include: { homeTeam: true, awayTeam: true, competition: true },
      orderBy: { kickoffAt: 'asc' },
    });
    await this.pub.set(key, JSON.stringify(rows), 'EX', 60);
    return rows;
  }

  /// Finished matches that have a curated highlight link, newest kickoff first.
  /// Backs the in-app Highlights screen. Cached briefly — admins add links
  /// sporadically, so 60s freshness is plenty.
  async getHighlights(limit = 60) {
    const key = `highlights:${limit}`;
    const cached = await this.pub.get(key);
    if (cached) return JSON.parse(cached);
    const rows = await this.prisma.match.findMany({
      where: { status: 'FINISHED', highlightUrl: { not: null } },
      include: { homeTeam: true, awayTeam: true, competition: true },
      orderBy: { kickoffAt: 'desc' },
      take: Math.min(100, Math.max(1, limit)),
    });
    await this.pub.set(key, JSON.stringify(rows), 'EX', 60);
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
