import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { AwardType } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';
import { GemsService } from '../gems/gems.service';

/// Award pick'em — golden boot / golden ball / best young player picks
/// made before kickoff and resolved at tournament close.
///
/// Scoring rule (simple v1): a correct pick = 150 gems + 100 bracket-style
/// points. Wrong = 0. Three picks per user per competition (one per award).
///
/// Lock semantics: once the competition's first match has kicked off,
/// `lockedAt` is stamped and edits are rejected.
@Injectable()
export class AwardsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly gems: GemsService,
  ) {}

  /// All three picks for the signed-in user in a competition.
  async myPicks(userId: string, competitionId: string) {
    const rows = await this.prisma.awardPick.findMany({
      where: { userId, competitionId },
      include: { player: { include: { team: true } } },
    });
    return rows;
  }

  /// Upsert a single award pick. Throws when the competition is already
  /// locked or the player isn't part of it.
  async submitPick(
    userId: string,
    competitionId: string,
    awardType: AwardType,
    playerId: string,
  ) {
    if (await this.isLocked(competitionId)) {
      throw new BadRequestException('awards_locked');
    }
    // Verify the player exists and is rostered in this competition. Cheap
    // guard against the user POSTing a player from another tournament.
    const player = await this.prisma.player.findUnique({
      where: { id: playerId },
      include: { team: { select: { competitionId: true } } },
    });
    if (!player) throw new NotFoundException('player_not_found');
    if (player.team.competitionId !== competitionId) {
      throw new BadRequestException('player_not_in_competition');
    }
    return this.prisma.awardPick.upsert({
      where: {
        userId_competitionId_awardType: { userId, competitionId, awardType },
      },
      create: { userId, competitionId, awardType, playerId },
      update: { playerId },
    });
  }

  /// Top players for each award category by rough proxy. Used to seed the
  /// picker UI so users don't have to scroll the entire roster.
  ///   - GOLDEN_BOOT  → players ranked by goals scored in the competition.
  ///   - GOLDEN_BALL  → players ranked by recent form (valuation rating).
  ///   - BEST_YOUNG   → players under 22 ranked by form.
  /// Falls back to alphabetical top-30 when no signal exists yet.
  async candidates(competitionId: string, awardType: AwardType, limit = 30) {
    if (awardType === 'GOLDEN_BOOT') {
      // Live goal counts from MatchEvent.GOAL in this competition.
      const goals = await this.prisma.matchEvent.groupBy({
        by: ['playerId'],
        where: {
          type: 'GOAL',
          playerId: { not: null },
          match: { competitionId },
        },
        _count: { _all: true },
        orderBy: { _count: { playerId: 'desc' } },
        take: limit,
      });
      const ids = goals.map((g) => g.playerId!).filter(Boolean);
      if (!ids.length) return this.fallbackRoster(competitionId, limit);
      const players = await this.prisma.player.findMany({
        where: { id: { in: ids } },
        include: { team: true },
      });
      // Preserve goal-count order from the groupBy.
      const byId = new Map(players.map((p) => [p.id, p]));
      return goals
        .map((g) => byId.get(g.playerId!))
        .filter((p): p is NonNullable<typeof p> => !!p);
    }

    // GOLDEN_BALL + BEST_YOUNG_PLAYER share the form-based sort.
    const cutoff = awardType === 'BEST_YOUNG_PLAYER'
      ? new Date(new Date().getFullYear() - 22, 0, 1)
      : undefined;
    return this.prisma.player.findMany({
      where: {
        team: { competitionId },
        ...(cutoff ? { dateOfBirth: { gte: cutoff } } : {}),
        valuation: { isNot: null },
      },
      include: { team: true, valuation: true },
      orderBy: { valuation: { recentForm: 'desc' } },
      take: limit,
    });
  }

  private async fallbackRoster(competitionId: string, limit: number) {
    return this.prisma.player.findMany({
      where: { team: { competitionId } },
      include: { team: true },
      orderBy: { name: 'asc' },
      take: limit,
    });
  }

  /// True once the first match in the competition has kicked off.
  private async isLocked(competitionId: string): Promise<boolean> {
    const first = await this.prisma.match.findFirst({
      where: { competitionId },
      orderBy: { kickoffAt: 'asc' },
      select: { kickoffAt: true },
    });
    return !!first && first.kickoffAt.getTime() <= Date.now();
  }

  /// Resolve all award picks for a competition. Idempotent — re-runs that
  /// don't change picks won't double-credit gems because of the
  /// (userId, source, refType, refId) dedupe key in GemTransaction.
  ///
  /// Caller passes the canonical winners (looked up by an admin / cron
  /// when the tournament ends — there's no AwardWinner table yet; if you
  /// add one later, swap in a DB lookup here).
  async resolve(
    competitionId: string,
    winners: Partial<Record<AwardType, string>>,
  ) {
    const types: AwardType[] = ['GOLDEN_BOOT', 'GOLDEN_BALL', 'BEST_YOUNG_PLAYER'];
    let updated = 0;
    for (const awardType of types) {
      const winnerId = winners[awardType];
      if (!winnerId) continue;
      const picks = await this.prisma.awardPick.findMany({
        where: { competitionId, awardType },
      });
      for (const p of picks) {
        const correct = p.playerId === winnerId;
        const pts = correct ? 100 : 0;
        if (p.pointsAwarded !== pts || p.scoredAt == null) {
          await this.prisma.awardPick.update({
            where: { id: p.id },
            data: { pointsAwarded: pts, scoredAt: new Date() },
          });
          updated++;
          if (correct) {
            // 150 gems per correct award — sits above bracket-group-winner
            // (15) and below bracket-champion (250). Dedupe-safe.
            await this.gems.credit({
              userId: p.userId,
              amount: 150,
              source: 'ADJUSTMENT',
              description: `${awardType.replace(/_/g, ' ').toLowerCase()} pick correct`,
              refType: 'award',
              refId: `${competitionId}:${awardType}`,
            });
          }
        }
      }
    }
    return { updated };
  }
}
