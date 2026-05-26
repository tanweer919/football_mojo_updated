import { BadRequestException, ForbiddenException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { H2HStatus } from '@prisma/client';
import * as crypto from 'crypto';
import { PrismaService } from '../../common/prisma.service';
import { PushService } from '../notifications/push.service';

@Injectable()
export class H2HService {
  private readonly log = new Logger(H2HService.name);
  constructor(
    private readonly prisma: PrismaService,
    private readonly push: PushService,
  ) {}

  /**
   * Propose a 1v1 challenge.
   *   - With opponentId: addressed challenge (the old behaviour).
   *   - Without opponentId: open invite — generates a unique `inviteToken`
   *     and returns it. Anyone with the link can accept (except the
   *     challenger). Used by the share-by-link UX so users don't have to
   *     copy-paste user IDs.
   */
  async propose(
    challengerId: string,
    opponentRef: string | null | undefined,
    gameweekId: string,
    message?: string,
  ) {
    // Accept either a Firebase uid or an @-prefixed userTag in `opponentRef`.
    // @tag lookups normalise the trailing tag to lowercase since `userTag`
    // is stored already-lowercased for case-insensitive uniqueness.
    let opponentId: string | null = null;
    if (opponentRef) {
      if (opponentRef.startsWith('@')) {
        const tag = opponentRef.slice(1).trim().toLowerCase();
        if (!tag) throw new BadRequestException('user_tag_empty');
        const target = await this.prisma.user.findUnique({
          where: { userTag: tag },
          select: { id: true },
        });
        if (!target) throw new NotFoundException('user_tag_not_found');
        opponentId = target.id;
      } else {
        opponentId = opponentRef.trim();
      }
    }

    if (opponentId && challengerId === opponentId)
      throw new BadRequestException('cannot_challenge_self');

    const gw = await this.prisma.fantasyGameweek.findUnique({ where: { id: gameweekId } });
    if (!gw) throw new NotFoundException('gameweek_not_found');
    if (gw.lockAt.getTime() <= Date.now()) throw new BadRequestException('gameweek_locked');

    if (opponentId) {
      const existing = await this.prisma.h2HChallenge.findFirst({
        where: { challengerId, opponentId, gameweekId, status: { in: ['PENDING', 'ACCEPTED'] } },
      });
      if (existing) throw new BadRequestException('duplicate_challenge');
    }

    const inviteToken = opponentId ? null : this.generateToken();

    return this.prisma.h2HChallenge.create({
      data: {
        tournamentId: gw.tournamentId,
        gameweekId,
        challengerId,
        opponentId: opponentId ?? null,
        inviteToken,
        message: message ?? null,
        status: 'PENDING',
      },
    });
  }

  /** Public preview of an invite — no auth required so the link works
   *  even before the recipient has signed in.  */
  async invitePreview(token: string) {
    const challenge = await this.prisma.h2HChallenge.findUnique({
      where: { inviteToken: token },
      include: {
        challenger: { select: { id: true, displayName: true, photoUrl: true, userTag: true } },
        gameweek: { select: { id: true, number: true, name: true, lockAt: true } },
        tournament: { select: { id: true, name: true, slug: true } },
      },
    });
    if (!challenge) throw new NotFoundException('invite_not_found');
    return {
      id: challenge.id,
      status: challenge.status,
      challenger: challenge.challenger,
      gameweek: challenge.gameweek,
      tournament: challenge.tournament,
      message: challenge.message,
      claimed: challenge.opponentId != null,
      expired: challenge.gameweek.lockAt.getTime() <= Date.now(),
    };
  }

  /** Accept an open invite. Fills in `opponentId` + ACCEPTED in one step.
   *  Notifies the challenger that someone has claimed their link. */
  async acceptInvite(token: string, userId: string) {
    const result = await this.prisma.$transaction(async (tx) => {
      const c = await tx.h2HChallenge.findUnique({ where: { inviteToken: token } });
      if (!c) throw new NotFoundException('invite_not_found');
      if (c.challengerId === userId)
        throw new BadRequestException('cannot_accept_own_invite');
      if (c.opponentId)
        throw new BadRequestException('already_claimed');
      if (c.status !== 'PENDING')
        throw new BadRequestException('not_pending');

      const gw = await tx.fantasyGameweek.findUnique({ where: { id: c.gameweekId } });
      if (!gw || gw.lockAt.getTime() <= Date.now())
        throw new BadRequestException('gameweek_locked');

      return tx.h2HChallenge.update({
        where: { id: c.id },
        data: { opponentId: userId, status: 'ACCEPTED' },
        include: {
          opponent: { select: { displayName: true, userTag: true } },
        },
      });
    });

    // Notify the challenger out-of-transaction so push latency doesn't
    // block the redemption response.
    const opponentName = result.opponent?.displayName
      ?? (result.opponent?.userTag != null ? `@${result.opponent.userTag}` : 'Someone');
    void this.push.pushToUser({
      userId: result.challengerId,
      category: 'h2hInvites',
      title: 'Challenge accepted',
      body: `${opponentName} accepted your 1v1 invite.`,
      data: {
        type: 'h2h_accepted',
        challengeId: result.id,
        deepLink: 'footballmojo://h2h',
      },
    });
    return result;
  }

  /** Public ladder for the WC — wins descending, with ties broken by win-rate. */
  async publicLadder(tournamentId?: string, limit = 100) {
    const where = tournamentId
      ? { tournamentId, status: 'RESOLVED' as const, winnerId: { not: null } }
      : { status: 'RESOLVED' as const, winnerId: { not: null } };
    const resolved = await this.prisma.h2HChallenge.findMany({
      where,
      select: { challengerId: true, opponentId: true, winnerId: true },
    });
    const wins = new Map<string, number>();
    const games = new Map<string, number>();
    for (const r of resolved) {
      for (const uid of [r.challengerId, r.opponentId]) {
        if (!uid) continue;
        games.set(uid, (games.get(uid) ?? 0) + 1);
      }
      if (r.winnerId) wins.set(r.winnerId, (wins.get(r.winnerId) ?? 0) + 1);
    }
    const userIds = [...new Set([...wins.keys(), ...games.keys()])];
    if (!userIds.length) return [];
    const users = await this.prisma.user.findMany({
      where: { id: { in: userIds } },
      select: { id: true, displayName: true, photoUrl: true, userTag: true, countryCode: true },
    });
    const rows = users.map((u) => ({
      userId: u.id,
      displayName: u.displayName,
      photoUrl: u.photoUrl,
      userTag: u.userTag,
      countryCode: u.countryCode,
      wins: wins.get(u.id) ?? 0,
      played: games.get(u.id) ?? 0,
    }));
    rows.sort((a, b) => {
      if (b.wins !== a.wins) return b.wins - a.wins;
      const ar = a.played === 0 ? 0 : a.wins / a.played;
      const br = b.played === 0 ? 0 : b.wins / b.played;
      return br - ar;
    });
    return rows.slice(0, limit).map((r, i) => ({ rank: i + 1, ...r }));
  }

  /** 16-char URL-safe token. Cryptographically random; collisions ignored
   *  because the unique index will throw on the create, and the caller
   *  is expected to retry on a duplicate-key error in the rare event. */
  private generateToken(): string {
    return crypto.randomBytes(12).toString('base64url').slice(0, 16);
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
      where: {
        gameweekId,
        status: { in: ['ACCEPTED', 'LOCKED'] },
        opponentId: { not: null }, // skip un-accepted open invites
      },
    });
    for (const c of active) {
      if (!c.opponentId) continue;
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

      // Push to both sides. Body framing differs based on outcome.
      const challenger = c.challengerId;
      const opponent   = c.opponentId;
      const data = {
        type: 'h2h_resolved',
        challengeId: c.id,
        deepLink: 'footballmojo://h2h',
      };
      const scoreLine = `${aScore.toFixed(1)} – ${bScore.toFixed(1)}`;
      const tiePush = (uid: string) => this.push.pushToUser({
        userId: uid, category: 'h2hResults',
        title: 'It\'s a draw', body: scoreLine, data,
      });
      const winPush = (uid: string) => this.push.pushToUser({
        userId: uid, category: 'h2hResults',
        title: 'You won your 1v1', body: scoreLine, data,
      });
      const lossPush = (uid: string) => this.push.pushToUser({
        userId: uid, category: 'h2hResults',
        title: 'You lost your 1v1', body: scoreLine, data,
      });

      if (winnerId === null) {
        await Promise.allSettled([tiePush(challenger), tiePush(opponent)]);
      } else if (winnerId === challenger) {
        await Promise.allSettled([winPush(challenger), lossPush(opponent)]);
      } else {
        await Promise.allSettled([lossPush(challenger), winPush(opponent)]);
      }
    }
  }
}
