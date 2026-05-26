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
  // Picks structure (flat map; one row per slot):
  //   GROUP_<letter>_1  → team id the user thinks finishes 1st  (3 pts if correct)
  //   GROUP_<letter>_2  → team id the user thinks finishes 2nd  (1 pt if correct)
  //   CHAMPION          → team id the user thinks lifts the cup (50 pts if correct)
  // Locks at the first knockout kickoff. Scoring is rerun each time a result
  // changes — totals are derived, not accumulated, so it stays idempotent.

  private static readonly BRACKET_POINTS = {
    GROUP_WINNER: 3,
    GROUP_RUNNER_UP: 1,
    CHAMPION: 50,
  };

  async submitBracket(userId: string, competitionId: string, picks: Record<string, string>) {
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
      picks: row.picks as Record<string, string>,
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

  // Rerun scoring for every bracket in a competition. Idempotent — call this
  // from a cron after group standings refresh, and again when the final ends.
  async scoreBracket(competitionId: string) {
    const groups = await this.prisma.group.findMany({
      where: { competitionId },
      include: {
        standings: { orderBy: { position: 'asc' }, include: { team: true } },
      },
    });
    const winners = new Map<string, string>();      // GROUP_A_1 → teamId
    const runnersUp = new Map<string, string>();    // GROUP_A_2 → teamId
    for (const g of groups) {
      const letter = g.name.replace(/^Group\s+/i, '').trim() || g.name;
      const positionLocked = (s: typeof g.standings[number]) =>
        s.played > 0 && s.played === (g.standings[0]?.played ?? 0);
      // Only count standings once every team has played the same number of games.
      const allEqual = g.standings.every(positionLocked);
      if (!allEqual) continue;
      const final = g.standings.length >= 2
        && g.standings[0]!.played > 0
        && g.standings.every((s) => s.played >= 3);
      if (!final) continue;
      winners.set(`GROUP_${letter}_1`, g.standings[0]!.team.id);
      runnersUp.set(`GROUP_${letter}_2`, g.standings[1]!.team.id);
    }

    // Champion = winner of the final match in the competition, if FINISHED.
    const finalMatch = await this.prisma.match.findFirst({
      where: { competitionId, stage: 'FINAL', status: 'FINISHED' },
    });
    let champion: string | null = null;
    if (finalMatch) {
      if (finalMatch.homeScore !== finalMatch.awayScore) {
        champion = finalMatch.homeScore > finalMatch.awayScore
          ? finalMatch.homeTeamId : finalMatch.awayTeamId;
      } else if (finalMatch.homePenalties != null && finalMatch.awayPenalties != null) {
        champion = finalMatch.homePenalties > finalMatch.awayPenalties
          ? finalMatch.homeTeamId : finalMatch.awayTeamId;
      }
    }

    const brackets = await this.prisma.bracket.findMany({ where: { competitionId } });
    let updated = 0;
    for (const b of brackets) {
      const picks = (b.picks ?? {}) as Record<string, string>;
      let pts = 0;
      for (const [slot, teamId] of winners.entries()) {
        if (picks[slot] === teamId) {
          pts += PredictionsService.BRACKET_POINTS.GROUP_WINNER;
          // Gems credit is idempotent via the (userId, source, bracket:slot) key.
          await this.gems.creditBracket(b.userId, b.id, slot, 'group_winner');
        }
      }
      for (const [slot, teamId] of runnersUp.entries()) {
        if (picks[slot] === teamId) {
          pts += PredictionsService.BRACKET_POINTS.GROUP_RUNNER_UP;
          await this.gems.creditBracket(b.userId, b.id, slot, 'runner_up');
        }
      }
      if (champion && picks['CHAMPION'] === champion) {
        pts += PredictionsService.BRACKET_POINTS.CHAMPION;
        await this.gems.creditBracket(b.userId, b.id, 'CHAMPION', 'champion');
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
