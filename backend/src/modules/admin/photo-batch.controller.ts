import { Controller, Get, Patch, Body, Query, UseGuards, CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma.service';

/**
 * Internal-only endpoints for the photo refresh script.
 * Guarded by INTERNAL_API_KEY — set this env var in production.
 */
@Injectable()
class InternalApiKeyGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest();
    const key = process.env.INTERNAL_API_KEY;
    if (!key) return true; // Allow in dev when key is not set
    const provided = req.headers['x-api-key'];
    if (provided !== key) {
      throw new UnauthorizedException('Invalid or missing x-api-key');
    }
    return true;
  }
}

@Controller({ path: 'internal/photos', version: '1' })
@UseGuards(InternalApiKeyGuard)
export class PhotoBatchController {
  constructor(private readonly prisma: PrismaService) {}

  @Get('pending')
  async pending(
    @Query('page') page?: string,
    @Query('pageSize') pageSize?: string,
  ) {
    const p = Math.max(1, Number(page ?? 1));
    const ps = Math.min(200, Math.max(1, Number(pageSize ?? 100)));
    // Return ALL players — the local script handles skip logic.
    const [rows, total] = await Promise.all([
      this.prisma.player.findMany({
        select: {
          id: true, name: true, photoUrl: true, nationality: true,
          team: { select: { name: true, shortName: true } },
        },
        orderBy: { name: 'asc' },
        take: ps,
        skip: (p - 1) * ps,
      }),
      this.prisma.player.count(),
    ]);
    return { rows, total, page: p, pageSize: ps };
  }

  @Patch('batch')
  async batch(@Body() body: { updates: { playerId: string; photoUrl: string }[] }) {
    const updates = body.updates ?? [];
    if (!updates.length) return { updated: 0 };
    const ops = updates.flatMap((u) => [
      this.prisma.player.update({ where: { id: u.playerId }, data: { photoUrl: u.photoUrl } }),
      this.prisma.cardTemplate.updateMany({ where: { playerId: u.playerId }, data: { artUrl: u.photoUrl } }),
    ]);
    await this.prisma.$transaction(ops);
    return { updated: updates.length };
  }
}
