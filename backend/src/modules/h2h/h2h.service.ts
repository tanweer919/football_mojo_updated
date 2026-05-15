import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { H2HStatus } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';

@Injectable()
export class H2HService {
  constructor(private readonly prisma: PrismaService) {}

  async propose(challengerId: string, opponentId: string, gameweekId: string, message?: string) {
    if (challengerId === opponentId) throw new BadRequestException('cannot_challenge_self');
    const gw = await this.prisma.fantasyGameweek.findUnique({ where: { id: gameweekId } });
    if (!gw) throw new NotFoundException('gameweek_not_found');
    if (gw.lockAt.getTime() <= Date.now()) throw new BadRequestException('gameweek_locked');

    // Single challenge per (challenger,opponent,gameweek) keeps history clean.
    const existing = await this.prisma.h2HChallenge.findFirst({
      where: { challengerId, opponentId, gameweekId, status: { in: ['PENDING', 'ACCEPTED'] } },
    });
    if (existing) throw new BadRequestException('duplicate_challenge');

    return this.prisma.h2HChallenge.create({
      data: {
        tournamentId: gw.tournamentId,
        gameweekId,
        challengerId,
        opponentId,
        message: message ?? null,
        status: 'PENDING',
      },
    });
  }

  async respond(challengeId: string, opponentId: string, decision: 'ACCEPTED' | 'DECLINED') {
    const c = await this.prisma.h2HChallenge.findUnique({ where: { id: challengeId } });
    if (!c) throw new NotFoundException('challenge_not_found');
    if (c.opponentId !== opponentId) throw new ForbiddenException('not_opponent');
    if (c.status !== 'PENDING') throw new BadRequestException('not_pending');
    return this.prisma.h2HChallenge.update({
      where: { id: challengeId },
      data: { status: decision, resolvedAt: decision === 'DECLINED' ? new Date() : null },
    });
  }

  async cancel(challengeId: string, challengerId: string) {
    const c = await this.prisma.h2HChallenge.findUnique({ where: { id: challengeId } });
    if (!c) throw new NotFoundException('challenge_not_found');
    if (c.challengerId !== challengerId) throw new ForbiddenException('not_challenger');
    if (c.status !== 'PENDING') throw new BadRequestException('not_pending');
    return this.prisma.h2HChallenge.update({
      where: { id: challengeId },
      data: { status: 'CANCELLED', resolvedAt: new Date() },
    });
  }

  async listMine(userId: string, status?: H2HStatus) {
    const where = status
      ? { OR: [{ challengerId: userId }, { opponentId: userId }], status }
      : { OR: [{ challengerId: userId }, { opponentId: userId }] };
    return this.prisma.h2HChallenge.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      include: {
        challenger: { select: { id: true, displayName: true, photoUrl: true } },
        opponent:   { select: { id: true, displayName: true, photoUrl: true } },
        gameweek:   { select: { id: true, number: true, name: true, lockAt: true } },
      },
    });
  }

  /**
   * Called after FantasyService scoreGameweek finishes. Resolves every ACCEPTED
   * challenge in this gameweek by comparing each player's lineup totals.
   */
  async resolveForGameweek(gameweekId: string) {
    const active = await this.prisma.h2HChallenge.findMany({
      where: { gameweekId, status: { in: ['ACCEPTED', 'LOCKED'] } },
    });
    for (const c of active) {
      const [a, b] = await Promise.all([
        this.prisma.fantasyLineup.findUnique({
          where: { userId_gameweekId: { userId: c.challengerId, gameweekId } },
        }),
        this.prisma.fantasyLineup.findUnique({
          where: { userId_gameweekId: { userId: c.opponentId, gameweekId } },
        }),
      ]);
      const aScore = a?.totalPoints ?? 0;
      const bScore = b?.totalPoints ?? 0;
      const winnerId = aScore === bScore ? null : aScore > bScore ? c.challengerId : c.opponentId;

      await this.prisma.h2HChallenge.update({
        where: { id: c.id },
        data: {
          challengerScore: aScore,
          opponentScore: bScore,
          challengerLineupId: a?.id ?? null,
          opponentLineupId: b?.id ?? null,
          winnerId,
          status: 'RESOLVED',
          resolvedAt: new Date(),
        },
      });
    }
  }
}
