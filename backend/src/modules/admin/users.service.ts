import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import { PrismaService } from '../../common/prisma.service';

@Injectable()
export class AdminUsersService {
  constructor(private readonly prisma: PrismaService) {}

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
          photoUrl: true, createdAt: true,
        },
      }),
      this.prisma.user.count({ where }),
      this.prisma.user.count({ where: { role: { in: ['ADMIN', 'SUPERADMIN'] } } }),
    ]);
    return { rows, total, adminTotal };
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
