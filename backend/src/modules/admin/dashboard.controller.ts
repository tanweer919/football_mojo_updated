import { Controller, Get, Req, UseGuards } from '@nestjs/common';
import { Request } from 'express';
import { PrismaService } from '../../common/prisma.service';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { AdminRoleGuard } from './admin-role.guard';

/**
 * Dashboard counts — runs every query in parallel so this stays a single
 * round-trip from the admin panel's perspective.
 */
@Controller({ path: 'admin', version: '1' })
@UseGuards(FirebaseAuthGuard, AdminRoleGuard)
export class AdminDashboardController {
  constructor(private readonly prisma: PrismaService) {}

  /// Lightweight identity probe — used by the admin shell to render the
  /// signed-in user's role in the topbar without round-tripping the full
  /// stats payload.
  @Get('me')
  async me(@Req() req: Request) {
    const u = await this.prisma.user.findUnique({
      where: { id: req.user!.uid },
      select: { id: true, email: true, displayName: true, role: true, photoUrl: true, userTag: true },
    });
    return u;
  }

  @Get('stats')
  async stats() {
    const [
      playersTotal, playersWithPhoto, playersWithCutout,
      cardsTotal, cardsMinted,
      usersTotal, admins,
      teamsTotal, competitionsTotal, matchesTotal,
    ] = await Promise.all([
      this.prisma.player.count(),
      this.prisma.player.count({ where: { photoUrl: { not: null } } }),
      this.prisma.player.count({ where: { photoUrl: { contains: 'thesportsdb.com' } } }),
      this.prisma.cardTemplate.count(),
      this.prisma.ownedCard.count(),
      this.prisma.user.count(),
      this.prisma.user.count({ where: { role: { in: ['ADMIN', 'SUPERADMIN'] } } }),
      this.prisma.team.count(),
      this.prisma.competition.count(),
      this.prisma.match.count(),
    ]);
    return {
      playersTotal, playersWithPhoto, playersWithCutout,
      cardsTotal, cardsMinted,
      usersTotal, admins,
      teamsTotal, competitionsTotal, matchesTotal,
    };
  }
}
