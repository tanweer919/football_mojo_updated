import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import { PrismaService } from '../../common/prisma.service';
import { GemsService } from '../gems/gems.service';

@Injectable()
export class AdminUsersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly gems: GemsService,
  ) {}

  async list(input: { q?: string; role?: UserRole; page: number; pageSize: number }) {
    const q = input.q?.trim();
    const where = {
      AND: [
        input.role ? { role: input.role } : {},
        q
          ? {
              OR: [
                { email: { contains: q, mode: 'insensitive' as const } },
                { displayName: { contains: q, mode: 'insensitive' as const } },
                { userTag: { contains: q.toLowerCase() } },
              ],
            }
          : {},
      ],
    };
    const [rows, total, adminTotal] = await Promise.all([
      this.prisma.user.findMany({
        where,
        orderBy: [{ role: 'desc' }, { createdAt: 'desc' }],
        take: input.pageSize,
        skip: (input.page - 1) * input.pageSize,
        select: {
          id: true, email: true, displayName: true, userTag: true, role: true,
          photoUrl: true, createdAt: true, gems: true, coins: true, countryCode: true,
        },
      }),
      this.prisma.user.count({ where }),
      this.prisma.user.count({ where: { role: { in: ['ADMIN', 'SUPERADMIN'] } } }),
    ]);
    return { rows, total, adminTotal };
  }

  /// Full profile for the user-detail page: every useful field, relation
  /// counts, and the recent gem ledger. FCM tokens are reduced to a count —
  /// the raw device tokens are sensitive and never need surfacing.
  async getById(id: string) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      select: {
        id: true, email: true, displayName: true, userTag: true, role: true,
        photoUrl: true, countryCode: true, supportedCountryCode: true,
        coins: true, gems: true, proExpiresAt: true, favouriteTeams: true,
        fcmTokens: true, lastDailyClaimAt: true, welcomeCardSeenAt: true,
        createdAt: true, updatedAt: true,
        _count: {
          select: {
            ownedCards: true, predictions: true, fantasyLineups: true,
            achievements: true, gemTransactions: true, leagueMemberships: true,
          },
        },
      },
    });
    if (!user) throw new NotFoundException('user_not_found');

    // Resolve followed-team IDs to real teams (name + crest), preserving the
    // saved order and falling back to a bare id for any team that no longer
    // exists, so the panel shows crests and names instead of opaque codes.
    const teamRows = user.favouriteTeams.length
      ? await this.prisma.team.findMany({
          where: { id: { in: user.favouriteTeams } },
          select: { id: true, name: true, shortName: true, crestUrl: true, countryCode: true },
        })
      : [];
    const teamById = new Map(teamRows.map((t) => [t.id, t]));
    const favouriteTeamDetails = user.favouriteTeams.map(
      (tid) =>
        teamById.get(tid) ?? {
          id: tid, name: null, shortName: null, crestUrl: null, countryCode: null,
        },
    );

    // Fantasy leagues the user has joined (most recent first).
    const memberships = await this.prisma.fantasyLeagueMember.findMany({
      where: { userId: id },
      orderBy: { joinedAt: 'desc' },
      take: 20,
      select: {
        joinedAt: true,
        league: { select: { id: true, name: true, ownerId: true } },
      },
    });
    const leagues = memberships.map((m) => ({
      id: m.league.id,
      name: m.league.name,
      isOwner: m.league.ownerId === id,
      joinedAt: m.joinedAt,
    }));

    const gemHistory = await this.prisma.gemTransaction.findMany({
      where: { userId: id },
      orderBy: { createdAt: 'desc' },
      take: 12,
      select: {
        id: true, amount: true, source: true, description: true,
        balanceAfter: true, createdAt: true,
      },
    });

    const { fcmTokens, ...rest } = user;
    return {
      ...rest,
      favouriteTeamDetails,
      leagues,
      fcmTokenCount: fcmTokens.length,
      proActive: !!user.proExpiresAt && user.proExpiresAt.getTime() > Date.now(),
      gemHistory,
    };
  }

  /// Set a user's gem balance to an exact value, routed through the gem
  /// ledger (source ADJUSTMENT) so the change is audited like every other
  /// gem movement. Computes the delta and credits/debits accordingly; a
  /// unique refId means each admin edit applies (never deduped).
  async adjustGems(callerUid: string, targetUserId: string, newBalance: number, reason?: string) {
    if (!Number.isInteger(newBalance) || newBalance < 0) {
      throw new BadRequestException('balance_must_be_a_non_negative_integer');
    }
    const user = await this.prisma.user.findUnique({
      where: { id: targetUserId },
      select: { id: true, gems: true },
    });
    if (!user) throw new NotFoundException('user_not_found');

    const delta = newBalance - user.gems;
    if (delta === 0) return { balance: user.gems, changed: false };

    const refId = `admin:${callerUid}:${randomUUID()}`;
    const description = `Admin adjustment${reason?.trim() ? ` — ${reason.trim()}` : ''}`;
    const res = delta > 0
      ? await this.gems.credit({ userId: targetUserId, amount: delta, source: 'ADJUSTMENT', description, refType: 'admin-adjust', refId })
      : await this.gems.debit({ userId: targetUserId, amount: -delta, source: 'ADJUSTMENT', description, refType: 'admin-adjust', refId });
    return { balance: res.balance, changed: true };
  }

  /// Role change — caller's role must be SUPERADMIN (enforced via the
  /// `@RequireRole` decorator on the controller). Block self-demote so a
  /// SUPERADMIN can't accidentally lock themselves out.
  async setRole(callerUid: string, targetUserId: string, nextRole: UserRole) {
    if (callerUid === targetUserId && nextRole === 'USER') {
      throw new BadRequestException('cannot_demote_self');
    }
    const u = await this.prisma.user.findUnique({ where: { id: targetUserId }, select: { id: true } });
    if (!u) throw new NotFoundException('user_not_found');
    await this.prisma.user.update({ where: { id: targetUserId }, data: { role: nextRole } });
  }

  /// Promote an email, creating an admin shell row when no User exists yet.
  /// Mirrors the `admin:promote` CLI script so SUPERADMINs can do it from
  /// the UI without needing shell access.
  async invite(email: string, role: 'ADMIN' | 'SUPERADMIN') {
    const e = email.trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e)) {
      throw new BadRequestException('invalid_email');
    }
    const existing = await this.prisma.user.findUnique({
      where: { email: e },
      select: { id: true, role: true },
    });
    if (existing) {
      if (existing.role !== role) {
        await this.prisma.user.update({ where: { email: e }, data: { role } });
      }
      return { id: existing.id, created: false };
    }
    const created = await this.prisma.user.create({
      data: { id: `admin_${randomUUID()}`, email: e, role },
      select: { id: true },
    });
    return { id: created.id, created: true };
  }

  async setUserTag(targetUserId: string, rawTag: string) {
    const tag = rawTag.trim().toLowerCase();
    if (tag && !/^(?![._])(?!.*[._]{2})[a-z0-9._]{3,20}(?<![._])$/.test(tag)) {
      throw new BadRequestException('invalid_user_tag');
    }
    await this.prisma.user.update({
      where: { id: targetUserId },
      data: { userTag: tag || null },
    });
  }
}
