import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma.service';
import { MintingService } from '../cards/minting.service';
import { GemsService } from '../gems/gems.service';

// Skill-based prediction game. Users predict score; points awarded by accuracy.
// No stakes, no wagers, no money in or out. This is the cleanest possible halal mechanic.
@Injectable()
export class PredictionsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly minting: MintingService,
    private readonly gems: GemsService,
  ) {}

  async submit(userId: string, matchId: string, homeScore: number, awayScore: number) {
    if (homeScore < 0 || awayScore < 0 || homeScore > 30 || awayScore > 30)
      throw new BadRequestException('invalid_score');

    const match = await this.prisma.match.findUnique({ where: { id: matchId } });
    if (!match) throw new NotFoundException('match_not_found');
    if (match.kickoffAt.getTime() <= Date.now())
      throw new BadRequestException('match_already_started');

    return this.prisma.prediction.upsert({
      where: { userId_matchId: { userId, matchId } },
      create: { userId, matchId, homeScore, awayScore },
      update: { homeScore, awayScore },
    });
  }

  // Called once a match transitions to FINISHED. Awards points + collectibles.
  async scoreMatch(matchId: string) {
    const match = await this.prisma.match.findUnique({ where: { id: matchId } });
    if (!match || match.status !== 'FINISHED') return { scored: 0 };

    const predictions = await this.prisma.prediction.findMany({
      where: { matchId, scoredAt: null },
    });
    let scored = 0;

    for (const p of predictions) {
      const points = this.scoringRule({
        actualHome: match.homeScore,
        actualAway: match.awayScore,
        predHome: p.homeScore,
        predAway: p.awayScore,
      });

      await this.prisma.prediction.update({
        where: { id: p.id },
        data: { pointsAwarded: points, scoredAt: new Date() },
      });
      await this.prisma.user.update({
        where: { id: p.userId },
        data: { coins: { increment: points } },
      });

      // Award gems as the user-facing reward currency. Idempotent — re-scoring
      // the same match credits each prediction once.
      await this.gems.creditPredictionPoints(p.userId, p.id, points);

      // Perfect-score predictions earn a collectible card from a curated reward pool.
      // The template is selected deterministically by user id so identical performance
      // yields an identical award — no gharar.
      if (points >= 10) {
        await this.awardPerfectPredictionCard(p.userId);
      }
      scored++;
    }
    return { scored };
  }

  // 10 pts exact score, 6 pts correct result + goal difference, 3 pts correct result, 0 otherwise.
  private scoringRule(s: { actualHome: number; actualAway: number; predHome: number; predAway: number }) {
    const exact = s.predHome === s.actualHome && s.predAway === s.actualAway;
    if (exact) return 10;
    const actualDiff = s.actualHome - s.actualAway;
    const predDiff = s.predHome - s.predAway;
    const sameResult = Math.sign(actualDiff) === Math.sign(predDiff);
    if (sameResult && actualDiff === predDiff) return 6;
    if (sameResult) return 3;
    return 0;
  }

  private async awardPerfectPredictionCard(userId: string) {
    const pool = await this.prisma.cardTemplate.findMany({
      where: { edition: 'WC2026-PREDICTION-REWARD' },
      orderBy: { id: 'asc' },
    });
    if (!pool.length) return;
    const idx = this.hashToIndex(userId, pool.length);
    await this.minting.award({
      userId,
      templateId: pool[idx]!.id,
      source: 'PREDICTION_REWARD',
    });
  }

  private hashToIndex(s: string, mod: number): number {
    let h = 0;
    for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) | 0;
    return Math.abs(h) % mod;
  }

  async leaderboard(scope: 'global' | 'competition', competitionId?: string) {
    if (scope === 'competition' && !competitionId)
      throw new BadRequestException('competition_id_required');

    return this.prisma.$queryRawUnsafe<Array<{ userId: string; total: number; displayName: string | null }>>(
      `
      SELECT p."userId", u."displayName", SUM(p."pointsAwarded")::int AS total
      FROM "Prediction" p
      JOIN "Match" m ON m.id = p."matchId"
      JOIN "User"  u ON u.id = p."userId"
      ${competitionId ? `WHERE m."competitionId" = '${competitionId}'` : ''}
      GROUP BY p."userId", u."displayName"
      ORDER BY total DESC
      LIMIT 100;
      `,
    );
  }

  async myPredictions(userId: string) {
    return this.prisma.prediction.findMany({
      where: { userId },
      include: { match: { include: { homeTeam: true, awayTeam: true } } },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  // ───────────────────────────────────────────────────────────────────────────
  // BRACKET PREDICTOR
  // ───────────────────────────────────────────────────────────────────────────
  // Picks shape (mixed-value map stored in Bracket.picks JSON):
  //
  //   GROUP_<letter>_<pos>  → teamId       (pos 1..4 — full ordering per group)
  //   BEST_THIRDS           → string[]     (up to 8 group letters)
  //   MATCH_<n>_WINNER      → teamId       (one per knockout match 73..104)
  //
  // Scoring tiers per correct pick:
  //   Group pos 1 / 2 / 3 / 4          → 5 / 3 / 1 / 0
  //   Best-thirds letter qualified     → 5
  //   Match winners by round:
  //     R32 (73-88) → 10
  //     R16 (89-96) → 25
  //     QF (97-100) → 50
  //     SF (101-102) → 100
  //     Bronze (103) → 75
  //     Final (104) → 500    (= champion)
  //
  // Locks at the first knockout kickoff. Scoring rerun on every group-
  // standings refresh and every finished knockout. Idempotent because
  // totals are derived from current state, not accumulated.
  private static readonly BRACKET_POINTS = {
    GROUP_POS_1: 5,
    GROUP_POS_2: 3,
    GROUP_POS_3: 1,
    GROUP_POS_4: 0,
    BEST_THIRD: 5,
    R32_WINNER: 10,
    R16_WINNER: 25,
    QF_WINNER:  50,
    SF_WINNER:  100,
    BRONZE_WINNER: 75,
    FINAL_WINNER: 500,
  };

  /// Map bracket-match numbers to their knockout round + stage tag.
  /// FIFA's WC2026 fixture list: 73-88 R32, 89-96 R16, 97-100 QF, 101-102 SF,
  /// 103 bronze final, 104 grand final.
  private static readonly MATCH_NUMBER_STAGE: Record<number, {
    round: 'R32' | 'R16' | 'QF' | 'SF' | 'BRONZE' | 'FINAL';
    stage: string;  // matches Match.stage values written by the scores poller
    indexInStage: number;
  }> = (() => {
    const out: Record<number, { round: any; stage: string; indexInStage: number }> = {};
    const ranges: Array<[string, string, number, number]> = [
      ['R32', 'ROUND_OF_32', 73, 88],
      ['R16', 'ROUND_OF_16', 89, 96],
      ['QF',  'QUARTER',    97, 100],
      ['SF',  'SEMI',       101, 102],
      ['BRONZE', 'BRONZE',  103, 103],
      ['FINAL', 'FINAL',    104, 104],
    ];
    for (const [round, stage, start, end] of ranges) {
      for (let n = start as number; n <= (end as number); n++) {
        out[n] = { round, stage, indexInStage: n - (start as number) };
      }
    }
    return out;
  })();

  /// Picks is now a mixed shape — Record<string, string | string[]>.
  async submitBracket(userId: string, competitionId: string, picks: Record<string, any>) {
    const lock = await this.bracketLockTime(competitionId);
    if (lock && lock.getTime() <= Date.now())
      throw new BadRequestException('bracket_locked');

    if (Object.keys(picks).length === 0)
      throw new BadRequestException('picks_required');

    return this.prisma.bracket.upsert({
      where: { userId },
      create: { userId, competitionId, picks, lockedAt: lock },
      update: { picks, lockedAt: lock },
    });
  }

  async getMyBracket(userId: string, competitionId: string) {
    const row = await this.prisma.bracket.findUnique({ where: { userId } });
    if (!row || row.competitionId !== competitionId) return null;
    const lock = row.lockedAt ?? (await this.bracketLockTime(competitionId));
    return {
      id: row.id,
      competitionId: row.competitionId,
      picks: (row.picks ?? {}) as Record<string, any>,
      pointsAwarded: row.pointsAwarded,
      lockedAt: lock,
      isLocked: !!(lock && lock.getTime() <= Date.now()),
      updatedAt: row.updatedAt,
    };
  }

  async bracketLeaderboard(competitionId: string, limit = 100) {
    const brackets = await this.prisma.bracket.findMany({
      where: { competitionId },
      orderBy: [{ pointsAwarded: 'desc' }, { updatedAt: 'asc' }],
      take: limit,
      include: {
        user: { select: { id: true, displayName: true, photoUrl: true, countryCode: true } },
      },
    });
    return brackets.map((b, i) => ({
      rank: i + 1,
      userId: b.userId,
      displayName: b.user.displayName,
      photoUrl: b.user.photoUrl,
      countryCode: b.user.countryCode,
      total: b.pointsAwarded,
    }));
  }

  /// Idempotent re-score over every bracket in the competition. Safe to
  /// call from the cron after group standings refresh + after every
  /// knockout result.
  ///
  /// Scoring runs in three layers:
  ///   1. Per-group position scoring (5/3/1/0) — needs all group matches
  ///      played (3 per team).
  ///   2. Best-thirds picks (5 each) — checks which 3rd-placed teams
  ///      actually appear in R32 fixtures.
  ///   3. Knockout match winners (10/25/50/100/75/500 by round) — looks
  ///      up the actual DB match by stage + chronological order, decides
  ///      winner from score/penalties.
  async scoreBracket(competitionId: string) {
    const points = PredictionsService.BRACKET_POINTS;

    // ── (1) Resolve final group standings per letter ────────────────────
    const groupResults = new Map<string, string[]>(); // letter → [pos1, pos2, pos3, pos4] teamIds
    const groups = await this.prisma.group.findMany({
      where: { competitionId },
      include: {
        standings: { orderBy: { position: 'asc' }, include: { team: true } },
      },
    });
    for (const g of groups) {
      const letter = g.name.replace(/^Group\s+/i, '').trim() || g.name;
      // All teams must have played 3 games for positions to settle.
      const allPlayed = g.standings.length === 4 && g.standings.every((s) => s.played >= 3);
      if (!allPlayed) continue;
      const sorted = [...g.standings].sort((a, b) => a.position - b.position);
      groupResults.set(letter, sorted.map((s) => s.team.id));
    }

    // ── (2) Set of group letters whose 3rd-place team actually advanced ─
    const r32Matches = await this.prisma.match.findMany({
      where: { competitionId, stage: 'ROUND_OF_32' },
      select: { homeTeamId: true, awayTeamId: true },
    });
    const teamsInR32 = new Set<string>();
    for (const m of r32Matches) {
      teamsInR32.add(m.homeTeamId);
      teamsInR32.add(m.awayTeamId);
    }
    const advancingThirdLetters = new Set<string>();
    for (const [letter, ordered] of groupResults) {
      const thirdId = ordered[2];
      if (thirdId && teamsInR32.has(thirdId)) {
        advancingThirdLetters.add(letter);
      }
    }

    // ── (3) Bracket-match-number → actual winner ─────────────────────────
    const knockout = await this.prisma.match.findMany({
      where: {
        competitionId,
        status: 'FINISHED',
        stage: { in: ['ROUND_OF_32', 'ROUND_OF_16', 'QUARTER', 'SEMI', 'BRONZE', 'FINAL'] },
      },
      orderBy: { kickoffAt: 'asc' },
    });
    const byStage = new Map<string, typeof knockout>();
    for (const m of knockout) {
      if (!m.stage) continue;
      const list = byStage.get(m.stage) ?? [];
      list.push(m);
      byStage.set(m.stage, list);
    }
    const actualWinnerByMatch = new Map<number, string>();
    for (const [num, info] of Object.entries(PredictionsService.MATCH_NUMBER_STAGE)) {
      const dbMatch = byStage.get(info.stage)?.[info.indexInStage];
      if (!dbMatch) continue;
      const winner = this.matchWinner(dbMatch);
      if (winner) actualWinnerByMatch.set(Number(num), winner);
    }

    // ── Score every bracket ─────────────────────────────────────────────
    const brackets = await this.prisma.bracket.findMany({ where: { competitionId } });
    let updated = 0;
    for (const b of brackets) {
      const picks = (b.picks ?? {}) as Record<string, any>;
      let pts = 0;

      // Group positions (5/3/1/0 for pos 1/2/3/4).
      for (const [letter, ordered] of groupResults) {
        for (let pos = 1; pos <= 4; pos++) {
          const userTeam = picks[`GROUP_${letter}_${pos}`];
          const actualTeam = ordered[pos - 1];
          if (typeof userTeam !== 'string' || userTeam !== actualTeam) continue;
          if (pos === 1) {
            pts += points.GROUP_POS_1;
            await this.gems.creditBracket(b.userId, b.id, `GROUP_${letter}_1`, 'group_winner');
          } else if (pos === 2) {
            pts += points.GROUP_POS_2;
            await this.gems.creditBracket(b.userId, b.id, `GROUP_${letter}_2`, 'runner_up');
          } else if (pos === 3) {
            pts += points.GROUP_POS_3;
            // No gem reward for 3rd-place position alone — qualifying
            // happens via the separate BEST_THIRDS pick.
          }
          // pos 4: 0 pts (just a bonus completeness signal, no reward).
        }
      }

      // Best-thirds: per letter the user picked, did their 3rd actually advance.
      if (advancingThirdLetters.size > 0) {
        const userThirds = picks['BEST_THIRDS'];
        if (Array.isArray(userThirds)) {
          for (const letter of userThirds) {
            if (typeof letter !== 'string') continue;
            if (!advancingThirdLetters.has(letter)) continue;
            pts += points.BEST_THIRD;
            // Reuse r16_reach gem kind — same semantic: "your pick made it
            // into the bracket". Dedupe ref keeps each letter unique.
            await this.gems.creditBracket(
              b.userId, b.id, `BEST_THIRD:${letter}`, 'r16_reach',
            );
          }
        }
      }

      // Match winners — iterate every match where we know the actual winner.
      for (const [matchNum, actualWinner] of actualWinnerByMatch) {
        const userPick = picks[`MATCH_${matchNum}_WINNER`];
        if (typeof userPick !== 'string' || userPick !== actualWinner) continue;
        const info = PredictionsService.MATCH_NUMBER_STAGE[matchNum];
        if (!info) continue;

        const pointsForRound =
          info.round === 'R32'    ? points.R32_WINNER :
          info.round === 'R16'    ? points.R16_WINNER :
          info.round === 'QF'     ? points.QF_WINNER  :
          info.round === 'SF'     ? points.SF_WINNER  :
          info.round === 'BRONZE' ? points.BRONZE_WINNER :
          info.round === 'FINAL'  ? points.FINAL_WINNER  : 0;
        pts += pointsForRound;

        // Gem kind by round — reuse existing kinds where semantically
        // similar. The dedupe key includes the match number so each
        // correct pick credits exactly once.
        const kind =
          info.round === 'R32'    ? 'r16_reach' :
          info.round === 'R16'    ? 'qf_reach'  :
          info.round === 'QF'     ? 'sf_reach'  :
          info.round === 'SF'     ? 'finalist'  :
          info.round === 'BRONZE' ? 'finalist'  :
          /* FINAL */               'champion'   as
          ('r16_reach' | 'qf_reach' | 'sf_reach' | 'finalist' | 'champion');
        await this.gems.creditBracket(b.userId, b.id, `MATCH_${matchNum}`, kind);
      }

      if (pts !== b.pointsAwarded) {
        await this.prisma.bracket.update({
          where: { id: b.id },
          data: { pointsAwarded: pts },
        });
        updated++;
      }
    }
    return { scored: brackets.length, updated };
  }

  /// Determine the winner of a finished match. Returns null on draws with
  /// no penalty data (rare — knockout matches always resolve, but defensive).
  private matchWinner(m: {
    homeTeamId: string; awayTeamId: string;
    homeScore: number; awayScore: number;
    homePenalties: number | null; awayPenalties: number | null;
  }): string | null {
    if (m.homeScore > m.awayScore) return m.homeTeamId;
    if (m.awayScore > m.homeScore) return m.awayTeamId;
    if (m.homePenalties != null && m.awayPenalties != null) {
      if (m.homePenalties > m.awayPenalties) return m.homeTeamId;
      if (m.awayPenalties > m.homePenalties) return m.awayTeamId;
    }
    return null;
  }

  // First knockout kickoff = lock for the bracket. Falls back to first match
  // of the competition if no knockout stage is tagged yet.
  private async bracketLockTime(competitionId: string): Promise<Date | null> {
    const knockout = await this.prisma.match.findFirst({
      where: {
        competitionId,
        stage: { in: ['ROUND_OF_32', 'ROUND_OF_16', 'QUARTER', 'SEMI', 'FINAL'] },
      },
      orderBy: { kickoffAt: 'asc' },
      select: { kickoffAt: true },
    });
    if (knockout) return knockout.kickoffAt;
    const first = await this.prisma.match.findFirst({
      where: { competitionId },
      orderBy: { kickoffAt: 'asc' },
      select: { kickoffAt: true },
    });
    return first?.kickoffAt ?? null;
  }
}
