import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PlayerPosition } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';
import { PRICING } from './fantasy.constants';

/**
 * Daily-cron player pricing. Price moves with rolling-average fantasy points.
 * Position floor enforced so GKs / DEFs don't drop below scout-able prices.
 */
@Injectable()
export class FantasyPricingService {
  private readonly log = new Logger(FantasyPricingService.name);

  constructor(private readonly prisma: PrismaService) {}

  @Cron(CronExpression.EVERY_DAY_AT_3AM, { name: 'fantasy-pricing' })
  async repriceAll() {
    const valuations = await this.prisma.playerValuation.findMany({ include: { player: true } });
    if (!valuations.length) {
      this.log.warn('No player valuations to reprice — seed the players first.');
      return;
    }

    for (const v of valuations) {
      const recent = await this.prisma.playerGameweekScore.findMany({
        where: { playerId: v.playerId },
        orderBy: { updatedAt: 'desc' },
        take: PRICING.formWindow,
        select: { totalPoints: true },
      });
      const avg = recent.length ? recent.reduce((s, r) => s + r.totalPoints, 0) / recent.length : 0;

      // Linear price model: positionFloor + form contribution capped at maxPrice.
      const floor = this.positionFloor(v.position);
      const formContribution = Math.max(0, avg) * PRICING.formWeight;
      const next = Math.min(PRICING.maxPrice, Math.max(floor, floor + formContribution));

      await this.prisma.playerValuation.update({
        where: { id: v.id },
        data: { recentForm: avg, price: Number(next.toFixed(1)) },
      });
    }
    this.log.log(`Repriced ${valuations.length} players`);
  }

  private positionFloor(p: PlayerPosition): number {
    return p === 'FWD' ? 6 : p === 'MID' ? 5.5 : p === 'DEF' ? 4.5 : 4.0;
  }
}
