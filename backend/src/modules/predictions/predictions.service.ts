import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma.service';
import { MintingService } from '../cards/minting.service';

// Skill-based prediction game. Users predict score; points awarded by accuracy.
// No stakes, no wagers, no money in or out. This is the cleanest possible halal mechanic.
@Injectable()
export class PredictionsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly minting: MintingService,
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

  // Bracket predictor — pick winners through every round before kickoff.
  async submitBracket(userId: string, competitionId: string, picks: Record<string, string>) {
    return this.prisma.bracket.upsert({
      where: { userId },
      create: { userId, competitionId, picks },
      update: { picks },
    });
  }
}
