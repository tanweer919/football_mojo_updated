import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma.service';

/**
 * Profile-page data assembler. One round-trip from the client; the service
 * fans out to a handful of small queries and merges the result.
 */
@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async me(uid: string) {
    const [user, ownedCount, h2hWins, totalPoints, achievements, followedTeams] =
      await Promise.all([
        this.prisma.user.findUnique({ where: { id: uid } }),
        this.prisma.ownedCard.count({ where: { ownerId: uid } }),
        this.prisma.h2HChallenge.count({ where: { winnerId: uid } }),
        this.prisma.fantasyLineup.aggregate({
          where: { userId: uid },
          _sum: { totalPoints: true },
        }),
        this.prisma.userAchievement.findMany({
          where: { userId: uid },
          include: {
            achievement: { select: { id: true, name: true, description: true, iconUrl: true } },
          },
          orderBy: { unlockedAt: 'desc' },
        }),
        this._followedTeamsFor(uid),
      ]);

    if (!user) throw new NotFoundException('user_not_found');

    // Ownership rarity breakdown.
    const rarityBreakdown = await this.prisma.ownedCard.groupBy({
      by: ['templateId'],
      where: { ownerId: uid },
      _count: { _all: true },
    });
    const templates = rarityBreakdown.length
      ? await this.prisma.cardTemplate.findMany({
          where: { id: { in: rarityBreakdown.map((r) => r.templateId) } },
          select: { id: true, rarity: true },
        })
      : [];
    const rarityCount: Record<string, number> = {};
    for (const r of rarityBreakdown) {
      const t = templates.find((x) => x.id === r.templateId);
      if (!t) continue;
      rarityCount[t.rarity] = (rarityCount[t.rarity] ?? 0) + r._count._all;
    }

    return {
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoUrl,
      countryCode: user.countryCode,
      coins: user.coins,
      gems: user.gems,
      proExpiresAt: user.proExpiresAt,
      memberSince: user.createdAt,
      stats: {
        ownedCards: ownedCount,
        totalFantasyPoints: totalPoints._sum.totalPoints ?? 0,
        h2hWins,
        rarityCount,
      },
      achievements: achievements.map((a) => ({
        id: a.achievement.id,
        name: a.achievement.name,
        description: a.achievement.description,
        iconUrl: a.achievement.iconUrl,
        unlockedAt: a.unlockedAt,
      })),
      followedTeams,
    };
  }

  private async _followedTeamsFor(uid: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: uid },
      select: { favouriteTeams: true },
    });
    if (!user || !user.favouriteTeams.length) return [];
    return this.prisma.team.findMany({
      where: { id: { in: user.favouriteTeams } },
      select: {
        id: true, name: true, shortName: true, countryCode: true, crestUrl: true,
        competition: { select: { id: true, name: true } },
      },
    });
  }
}
