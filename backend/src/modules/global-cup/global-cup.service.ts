import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';
import { MintingService } from '../cards/minting.service';

/**
 * Sorare 2022 World Cup-style Global Cup.
 *
 * - Free-to-play: any signed-in user can enter (no fee, no stake → halal)
 * - One lineup per gameweek (FantasyLineup handles submission)
 * - Cumulative ranking across all gameweeks
 * - Top-N receive pre-defined special-edition cards (no randomness → halal)
 */
@Injectable()
export class GlobalCupService {
  private readonly log = new Logger(GlobalCupService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly minting: MintingService,
  ) {}

  async cumulativeLeaderboard(tournamentId: string, limit = 1000) {
    return this.prisma.$queryRawUnsafe<
      Array<{ userId: string; displayName: string | null; photoUrl: string | null; total: number; lineups: number; rank: number }>
    >(`
      SELECT
        l."userId",
        u."displayName",
        u."photoUrl",
        COALESCE(SUM(l."totalPoints"),0)::float AS total,
        COUNT(*)::int                            AS lineups,
        RANK() OVER (ORDER BY COALESCE(SUM(l."totalPoints"),0) DESC)::int AS rank
      FROM "FantasyLineup" l
      JOIN "FantasyGameweek" g ON g.id = l."gameweekId"
      JOIN "User" u            ON u.id = l."userId"
      WHERE g."tournamentId" = '${tournamentId}'
      GROUP BY l."userId", u."displayName", u."photoUrl"
      ORDER BY total DESC
      LIMIT ${limit};
    `);
  }

  async myRank(tournamentId: string, userId: string) {
    const rows = await this.prisma.$queryRawUnsafe<Array<{ rank: number; total: number }>>(`
      WITH leaderboard AS (
        SELECT l."userId",
               COALESCE(SUM(l."totalPoints"),0)::float AS total,
               RANK() OVER (ORDER BY COALESCE(SUM(l."totalPoints"),0) DESC) AS rank
        FROM "FantasyLineup" l
        JOIN "FantasyGameweek" g ON g.id = l."gameweekId"
        WHERE g."tournamentId" = '${tournamentId}'
        GROUP BY l."userId"
      )
      SELECT rank::int, total FROM leaderboard WHERE "userId" = '${userId}';
    `);
    return rows[0] ?? { rank: null, total: 0 };
  }

  async listPrizes(tournamentId: string) {
    return this.prisma.globalCupPrize.findMany({
      where: { tournamentId },
      orderBy: { rankFrom: 'asc' },
      include: { cardTemplate: true },
    });
  }

  /**
   * Distribute prizes when the tournament finishes. Idempotent —
   * already-awarded prize rows are skipped.
   */
  async distributePrizes(tournamentId: string) {
    const tournament = await this.prisma.fantasyTournament.findUnique({
      where: { id: tournamentId },
      include: { prizes: true },
    });
    if (!tournament) throw new NotFoundException('tournament_not_found');
    if (tournament.endsAt.getTime() > Date.now())
      throw new Error('tournament_not_finished');

    const ranking = await this.cumulativeLeaderboard(tournamentId, 100_000);
    const prizes = await this.listPrizes(tournamentId);

    let awardedCount = 0;
    for (const prize of prizes) {
      if (prize.awarded) continue;
      const winners = ranking.filter((r) => r.rank >= prize.rankFrom && r.rank <= prize.rankTo);
      for (const w of winners) {
        try {
          await this.minting.award({
            userId: w.userId,
            templateId: prize.cardTemplateId,
            source: 'ACHIEVEMENT',
          });
          awardedCount++;
        } catch (e) {
          this.log.warn(`Failed to mint prize for user ${w.userId}: ${(e as Error).message}`);
        }
      }
      await this.prisma.globalCupPrize.update({
        where: { id: prize.id },
        data: { awarded: true, awardedAt: new Date() },
      });
    }
    this.log.log(`Global Cup ${tournament.slug}: awarded ${awardedCount} prize cards`);
    return { awardedCount };
  }
}
