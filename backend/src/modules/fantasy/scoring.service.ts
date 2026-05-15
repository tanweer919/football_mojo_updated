import { Injectable, Logger } from '@nestjs/common';
import { PlayerPosition, Prisma } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';
import { ApiFootballCacheService } from '../api-football/api-football-cache.service';
import { ApiFixturePlayerStat } from '../api-football/api-football.client';
import {
  ALL_AROUND_CAP,
  ALL_AROUND_WEIGHTS,
  APPEARANCE_POINTS,
  BreakdownEntry,
  CAPTAIN_MULTIPLIER,
  DECISIVE,
  POSITION_RULES,
  SCORE_CEILING,
  SCORE_FLOOR,
} from './fantasy.constants';

interface PlayerLine {
  playerId: string;
  position: PlayerPosition;
  stat: ApiFixturePlayerStat['statistics'][0];
  teamCleanSheet: boolean;
  ownGoals: number;             // sourced from /fixtures/events — api-football doesn't expose it on /fixtures/players
}

@Injectable()
export class FantasyScoringService {
  private readonly log = new Logger(FantasyScoringService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly apiFootball: ApiFootballCacheService,
  ) {}

  // ───────────────────────────────────────────────────────────────────────────
  // PURE FUNCTION — testable without DB or HTTP.
  // Returns the total score and the full audit trail used by the UI.
  // ───────────────────────────────────────────────────────────────────────────
  scorePlayer(line: PlayerLine): { total: number; breakdown: BreakdownEntry[]; bucketTotals: Record<string, number> } {
    const breakdown: BreakdownEntry[] = [];
    const pos = line.position;
    const s = line.stat;
    const minutes = s.games.minutes ?? 0;

    if (minutes <= 0) {
      return {
        total: 0,
        breakdown: [{ key: 'dnp', bucket: 'allAround', label: 'Did not play', count: 0, points: 0 }],
        bucketTotals: { appearance: 0, allAround: 0, decisive: 0, position: 0 },
      };
    }

    // ── Appearance ──────────────────────────────────────────────────────
    let appearancePts = APPEARANCE_POINTS.played;
    breakdown.push({ key: 'appearance', bucket: 'allAround', label: 'Played', count: 1, points: APPEARANCE_POINTS.played });
    if (minutes >= 60) {
      appearancePts += APPEARANCE_POINTS.played60;
      breakdown.push({ key: 'played60', bucket: 'allAround', label: '60+ minutes', count: 1, points: APPEARANCE_POINTS.played60 });
    }

    // ── All-Around ──────────────────────────────────────────────────────
    let allAround = 0;
    const passes      = s.passes.total ?? 0;
    const accuracyPct = parsePercent(s.passes.accuracy);
    const duelsWon    = s.duels.won ?? 0;
    const foulsDrawn  = s.fouls.drawn ?? 0;
    const foulsComm   = s.fouls.committed ?? 0;
    const offsides    = s.offsides ?? 0;

    const w = ALL_AROUND_WEIGHTS[pos];
    if (w.pass && passes) {
      const pts = round1(passes * w.pass);
      allAround += pts;
      breakdown.push({ key: 'passes', bucket: 'allAround', label: 'Passes', count: passes, points: pts });
    }
    if (w.accurate_pass_bonus && accuracyPct >= 0.85) {
      const pts = w.accurate_pass_bonus;
      allAround += pts;
      breakdown.push({ key: 'pass_accuracy', bucket: 'allAround', label: 'Pass accuracy ≥85%', count: 1, points: pts });
    }
    if (w.duel_won && duelsWon) {
      const pts = round1(duelsWon * w.duel_won);
      allAround += pts;
      breakdown.push({ key: 'duels_won', bucket: 'allAround', label: 'Duels won', count: duelsWon, points: pts });
    }
    if (w.foul_drawn && foulsDrawn) {
      const pts = round1(foulsDrawn * w.foul_drawn);
      allAround += pts;
      breakdown.push({ key: 'fouls_drawn', bucket: 'allAround', label: 'Fouls drawn', count: foulsDrawn, points: pts });
    }
    if (w.foul_committed && foulsComm) {
      const pts = round1(foulsComm * w.foul_committed);
      allAround += pts;
      breakdown.push({ key: 'fouls_committed', bucket: 'allAround', label: 'Fouls committed', count: foulsComm, points: pts });
    }
    if (w.offside && offsides) {
      const pts = round1(offsides * w.offside);
      allAround += pts;
      breakdown.push({ key: 'offsides', bucket: 'allAround', label: 'Offsides', count: offsides, points: pts });
    }
    allAround = clamp(allAround, -ALL_AROUND_CAP, ALL_AROUND_CAP);

    // ── Decisive ────────────────────────────────────────────────────────
    let decisive = 0;
    const goals     = s.goals.total ?? 0;
    const assists   = s.goals.assists ?? 0;
    const conceded  = s.goals.conceded ?? 0;
    const yellow    = s.cards.yellow;
    const red       = s.cards.red;
    const penScored = s.penalty.scored;
    const penMissed = s.penalty.missed;
    const penWon    = s.penalty.won ?? 0;
    const penCommit = s.penalty.commited ?? 0;

    const openGoals = Math.max(0, goals - penScored);
    if (openGoals) {
      const pts = openGoals * DECISIVE.goal[pos];
      decisive += pts;
      breakdown.push({ key: 'goal', bucket: 'decisive', label: 'Goals (open play)', count: openGoals, points: pts });
    }
    if (penScored) {
      const pts = penScored * DECISIVE.penaltyGoal[pos];
      decisive += pts;
      breakdown.push({ key: 'pen_goal', bucket: 'decisive', label: 'Penalty goals', count: penScored, points: pts });
    }
    if (assists) {
      const pts = assists * DECISIVE.assist[pos];
      decisive += pts;
      breakdown.push({ key: 'assist', bucket: 'decisive', label: 'Assists', count: assists, points: pts });
    }
    if (line.teamCleanSheet && minutes >= 60 && DECISIVE.cleanSheet[pos]) {
      const pts = DECISIVE.cleanSheet[pos];
      decisive += pts;
      breakdown.push({ key: 'clean_sheet', bucket: 'decisive', label: 'Clean sheet', count: 1, points: pts });
    }
    if (!line.teamCleanSheet && conceded >= 2 && DECISIVE.twoConceded[pos]) {
      const pts = DECISIVE.twoConceded[pos];
      decisive += pts;
      breakdown.push({ key: 'two_conceded', bucket: 'decisive', label: '2+ goals conceded', count: 1, points: pts });
    }
    if (penMissed) {
      const pts = penMissed * DECISIVE.penaltyMiss;
      decisive += pts;
      breakdown.push({ key: 'pen_missed', bucket: 'decisive', label: 'Missed penalty', count: penMissed, points: pts });
    }
    if (penWon) {
      const pts = penWon * DECISIVE.penaltyWon;
      decisive += pts;
      breakdown.push({ key: 'pen_won', bucket: 'decisive', label: 'Penalty won', count: penWon, points: pts });
    }
    if (penCommit) {
      const pts = penCommit * DECISIVE.penaltyCommit;
      decisive += pts;
      breakdown.push({ key: 'pen_commit', bucket: 'decisive', label: 'Penalty conceded', count: penCommit, points: pts });
    }
    if (yellow)        { const pts = yellow        * DECISIVE.yellowCard; decisive += pts; breakdown.push({ key: 'yellow',   bucket: 'decisive', label: 'Yellow card',  count: yellow, points: pts }); }
    if (red)           { const pts = red           * DECISIVE.redCard;    decisive += pts; breakdown.push({ key: 'red',      bucket: 'decisive', label: 'Red card',     count: red,    points: pts }); }
    if (line.ownGoals) { const pts = line.ownGoals * DECISIVE.ownGoal;    decisive += pts; breakdown.push({ key: 'own_goal', bucket: 'decisive', label: 'Own goal',     count: line.ownGoals, points: pts }); }
    decisive = clamp(decisive, DECISIVE.floor, DECISIVE.cap);

    // ── Position-specific ──────────────────────────────────────────────
    let position = 0;
    if (pos === 'GK') {
      const saves    = s.goals.saves ?? 0;
      const penSaves = s.penalty.saved;
      if (saves)    { const pts = round1(saves    * POSITION_RULES.GK.savePerOne); position += pts; breakdown.push({ key: 'saves',           bucket: 'position', label: 'Saves',          count: saves,    points: pts }); }
      if (penSaves) { const pts = penSaves       * POSITION_RULES.GK.penaltySave;  position += pts; breakdown.push({ key: 'pen_saves',       bucket: 'position', label: 'Penalty saves',  count: penSaves, points: pts }); }
      if (conceded) { const pts = round1(conceded * POSITION_RULES.GK.conceded);   position += pts; breakdown.push({ key: 'goals_conceded',  bucket: 'position', label: 'Goals conceded', count: conceded, points: pts }); }
    } else if (pos === 'DEF') {
      const blocks  = s.tackles.blocks ?? 0;
      const inters  = s.tackles.interceptions ?? 0;
      const tackles = s.tackles.total ?? 0;
      if (blocks)   { const pts = round1(blocks   * POSITION_RULES.DEF.block);        position += pts; breakdown.push({ key: 'blocks',        bucket: 'position', label: 'Blocks',           count: blocks,   points: pts }); }
      if (inters)   { const pts = round1(inters   * POSITION_RULES.DEF.interception); position += pts; breakdown.push({ key: 'interceptions', bucket: 'position', label: 'Interceptions',    count: inters,   points: pts }); }
      if (tackles)  { const pts = round1(tackles  * POSITION_RULES.DEF.tackle);       position += pts; breakdown.push({ key: 'tackles',       bucket: 'position', label: 'Tackles',          count: tackles,  points: pts }); }
      if (duelsWon) { const pts = round1(duelsWon * POSITION_RULES.DEF.duelWon);      position += pts; breakdown.push({ key: 'duels_won_def', bucket: 'position', label: 'Def. duels won',   count: duelsWon, points: pts }); }
    } else if (pos === 'MID') {
      const keyPasses = s.passes.key ?? 0;
      const completed = Math.round(passes * accuracyPct);
      const tackles   = s.tackles.total ?? 0;
      const dribOk    = s.dribbles.success ?? 0;
      if (keyPasses) { const pts = round1(keyPasses * POSITION_RULES.MID.keyPass);             position += pts; breakdown.push({ key: 'key_passes',       bucket: 'position', label: 'Key passes',          count: keyPasses, points: pts }); }
      if (completed) { const pts = round1(completed * POSITION_RULES.MID.completedPass);       position += pts; breakdown.push({ key: 'completed_passes', bucket: 'position', label: 'Completed passes',    count: completed, points: pts }); }
      if (dribOk)    { const pts = round1(dribOk    * POSITION_RULES.MID.successfulDribble);   position += pts; breakdown.push({ key: 'dribbles',         bucket: 'position', label: 'Successful dribbles', count: dribOk,    points: pts }); }
      if (tackles)   { const pts = round1(tackles   * POSITION_RULES.MID.tackle);              position += pts; breakdown.push({ key: 'tackles_mid',      bucket: 'position', label: 'Tackles',             count: tackles,   points: pts }); }
    } else if (pos === 'FWD') {
      const shotsOn    = s.shots.on ?? 0;
      const shotsTotal = s.shots.total ?? 0;
      const shotsBlk   = Math.max(0, shotsTotal - shotsOn);
      const keyPasses  = s.passes.key ?? 0;
      const dribOk     = s.dribbles.success ?? 0;
      if (shotsOn)   { const pts = round1(shotsOn   * POSITION_RULES.FWD.shotOnTarget);     position += pts; breakdown.push({ key: 'shots_on_target', bucket: 'position', label: 'Shots on target',    count: shotsOn,  points: pts }); }
      if (shotsBlk)  { const pts = round1(shotsBlk  * POSITION_RULES.FWD.shotBlockedByDef); position += pts; breakdown.push({ key: 'shots_blocked',   bucket: 'position', label: 'Shots blocked',      count: shotsBlk, points: pts }); }
      if (dribOk)    { const pts = round1(dribOk    * POSITION_RULES.FWD.successfulDribble);position += pts; breakdown.push({ key: 'dribbles_fwd',    bucket: 'position', label: 'Successful dribbles', count: dribOk,  points: pts }); }
      if (keyPasses) { const pts = round1(keyPasses * POSITION_RULES.FWD.keyPass);          position += pts; breakdown.push({ key: 'key_passes_fwd',  bucket: 'position', label: 'Key passes',          count: keyPasses, points: pts }); }
    }
    position = clamp(position, 0, POSITION_RULES.cap);

    const total = clamp(appearancePts + allAround + decisive + position, SCORE_FLOOR, SCORE_CEILING);
    return {
      total: round1(total),
      breakdown,
      bucketTotals: {
        appearance: appearancePts,
        allAround: round1(allAround),
        decisive: round1(decisive),
        position: round1(position),
      },
    };
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ORCHESTRATION
  // ───────────────────────────────────────────────────────────────────────────

  /** Pull every match in a gameweek, score every player, roll up lineup totals. */
  async scoreGameweek(gameweekId: string) {
    const gw = await this.prisma.fantasyGameweek.findUnique({ where: { id: gameweekId } });
    if (!gw) throw new Error(`gameweek_not_found: ${gameweekId}`);

    let scored = 0;
    for (const matchId of gw.matchIds) {
      try {
        scored += await this.scoreFixture(matchId, gameweekId);
      } catch (err) {
        this.log.error(`Scoring fixture ${matchId} failed: ${(err as Error).message}`);
      }
    }
    await this.rollupLineups(gameweekId);
    await this.prisma.fantasyGameweek.update({ where: { id: gameweekId }, data: { scored: true } });
    this.log.log(`Gameweek ${gw.number} scored: ${scored} player rows`);
    return { playerRows: scored };
  }

  /**
   * Score a single fixture. Safe to call repeatedly (once/min live + final at FT).
   * Idempotent: upserts PlayerGameweekScore by (playerId, gameweekId).
   */
  async scoreFixture(matchId: string, gameweekId: string): Promise<number> {
    const fixtureIdNum = Number(matchId);
    if (!Number.isFinite(fixtureIdNum)) return 0;

    // Match might still be live when scoring runs (live mid-match preview)
    // or finished (final scoring at FT). Pass isLive=false once FINISHED so
    // the cache layer freezes the upstream payload forever.
    const match = await this.prisma.match.findUnique({ where: { id: matchId } });
    const isLive = match?.status !== 'FINISHED';
    const [teams, events] = await Promise.all([
      this.apiFootball.fixturePlayers(fixtureIdNum, isLive),
      this.apiFootball.fixtureEvents(fixtureIdNum, isLive).catch(() => []),
    ]);
    if (!teams.length) return 0;

    // Own-goal counts per player (api-football puts own goals as Goal events
    // with detail "Own Goal" on the OPPOSING team's side).
    const ownGoalsByPlayer = new Map<number, number>();
    for (const e of events) {
      if (e.type === 'Goal' && /own goal/i.test(e.detail) && e.player.id != null) {
        ownGoalsByPlayer.set(e.player.id, (ownGoalsByPlayer.get(e.player.id) ?? 0) + 1);
      }
    }

    const cleanSheetByTeamId = new Map<string, boolean>();
    if (match) {
      cleanSheetByTeamId.set(match.homeTeamId, match.awayScore === 0);
      cleanSheetByTeamId.set(match.awayTeamId, match.homeScore === 0);
    }

    let count = 0;
    for (const t of teams) {
      const ourTeamId = String(t.team.id);
      const cs = cleanSheetByTeamId.get(ourTeamId) ?? false;
      for (const p of t.players) {
        const stat = p.statistics?.[0];
        if (!stat) continue;
        const playerId = String(p.player.id);
        const valuation = await this.prisma.playerValuation.findUnique({ where: { playerId } });
        const position = valuation?.position ?? this.inferPosition(stat.games.position);

        const { total, breakdown, bucketTotals } = this.scorePlayer({
          playerId,
          position,
          stat,
          teamCleanSheet: cs,
          ownGoals: ownGoalsByPlayer.get(p.player.id) ?? 0,
        });

        await this.prisma.playerGameweekScore.upsert({
          where: { playerId_gameweekId: { playerId, gameweekId } },
          create: {
            playerId, gameweekId,
            minutesPlayed: stat.games.minutes ?? 0,
            goals: stat.goals.total ?? 0,
            assists: stat.goals.assists ?? 0,
            cleanSheet: cs,
            yellowCards: stat.cards.yellow,
            redCards: stat.cards.red,
            saves: stat.goals.saves ?? 0,
            penaltyMisses: stat.penalty.missed,
            ownGoals: ownGoalsByPlayer.get(p.player.id) ?? 0,
            goalsConceded: stat.goals.conceded ?? 0,
            totalPoints: total,
            breakdown: { bucketTotals, entries: breakdown, raw: stat } as unknown as Prisma.InputJsonValue,
          },
          update: {
            minutesPlayed: stat.games.minutes ?? 0,
            goals: stat.goals.total ?? 0,
            assists: stat.goals.assists ?? 0,
            cleanSheet: cs,
            yellowCards: stat.cards.yellow,
            redCards: stat.cards.red,
            saves: stat.goals.saves ?? 0,
            penaltyMisses: stat.penalty.missed,
            ownGoals: ownGoalsByPlayer.get(p.player.id) ?? 0,
            goalsConceded: stat.goals.conceded ?? 0,
            totalPoints: total,
            breakdown: { bucketTotals, entries: breakdown, raw: stat } as unknown as Prisma.InputJsonValue,
          },
        });
        count++;
      }
    }
    return count;
  }

  async rollupLineups(gameweekId: string) {
    const lineups = await this.prisma.fantasyLineup.findMany({ where: { gameweekId } });
    if (!lineups.length) return;

    const playerIds = new Set<string>();
    for (const l of lineups) for (const p of l.picks as Array<{ playerId: string }>) playerIds.add(p.playerId);
    const scores = await this.prisma.playerGameweekScore.findMany({
      where: { gameweekId, playerId: { in: [...playerIds] } },
    });
    const scoreMap = new Map(scores.map((s) => [s.playerId, s.totalPoints]));

    const totals = lineups.map((l) => {
      const picks = l.picks as Array<{ playerId: string; isCaptain?: boolean }>;
      let total = 0;
      for (const p of picks) {
        const base = scoreMap.get(p.playerId) ?? 0;
        const captained = p.isCaptain || p.playerId === l.captainId;
        total += captained ? base * CAPTAIN_MULTIPLIER : base;
      }
      return { id: l.id, total: round1(total) };
    });

    await this.prisma.$transaction(
      totals.map((t) => this.prisma.fantasyLineup.update({
        where: { id: t.id },
        data: { totalPoints: t.total, scoredAt: new Date() },
      })),
    );

    totals.sort((a, b) => b.total - a.total);
    await this.prisma.$transaction(
      totals.map((t, i) => this.prisma.fantasyLineup.update({
        where: { id: t.id }, data: { rank: i + 1 },
      })),
    );
  }

  private inferPosition(raw: string | null | undefined): PlayerPosition {
    switch ((raw ?? '').toUpperCase()) {
      case 'G': return 'GK';
      case 'D': return 'DEF';
      case 'F': return 'FWD';
      default:  return 'MID';
    }
  }
}

function parsePercent(p: string | null | undefined): number {
  if (!p) return 0;
  const n = Number(p.replace('%', '').trim());
  return Number.isFinite(n) ? n / 100 : 0;
}
function round1(n: number): number { return Math.round(n * 10) / 10; }
function clamp(n: number, lo: number, hi: number): number { return Math.max(lo, Math.min(hi, n)); }
