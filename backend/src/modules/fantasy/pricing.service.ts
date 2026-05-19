import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PlayerPosition } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';
import { PRICING, TEAM_BOOST_BY_COMPETITION } from './fantasy.constants';

/**
 * Player pricing engine for the 100-pt / 5-player fantasy budget.
 *
 * Why the rewrite from the old "formula":
 *   The previous model was `floor + formAvg * weight`. Pre-season, with no
 *   `PlayerGameweekScore` rows yet, the form average is 0 → every player
 *   ends up priced at the position floor (~4-6 pts each). 5 floor-priced
 *   players cost ~25 pts vs the 100 budget — squad-building is meaningless
 *   because every option is affordable.
 *
 * The new model is additive across four independent boosts:
 *
 *   price = positionFloor + teamBoost + playerBoost + formBoost
 *           clamped to [PRICING.minPrice, PRICING.maxPrice]
 *
 *   - positionFloor — cheapest player at each position (GK 10 → FWD 13)
 *   - teamBoost     — 0..6 from a competition-tier lookup so Premier League
 *                     / WC players outprice 3rd-division players even with
 *                     identical stats.
 *   - playerBoost   — 0..6 from a stable hash of `player.id` (+ a nudge for
 *                     low shirt numbers — usually senior/starting XI).
 *                     Deterministic, so reseeds don't shuffle prices.
 *   - formBoost     — 0..8 from a rolling average of recent fantasy points.
 *                     Zero pre-season; ramps up as scores come in.
 *
 * Result: pre-season prices spread ~10–24 pts with realistic stratification,
 * and the cheapest legal squad already costs ~57 pts.
 */
@Injectable()
export class FantasyPricingService {
  private readonly log = new Logger(FantasyPricingService.name);

  constructor(private readonly prisma: PrismaService) {}

  @Cron(CronExpression.EVERY_DAY_AT_3AM, { name: 'fantasy-pricing' })
  async repriceAll() {
    const valuations = await this.prisma.playerValuation.findMany({
      include: {
        player: { include: { team: { include: { competition: { select: { id: true } } } } } },
      },
    });
    if (!valuations.length) {
      this.log.warn('No player valuations to reprice — seed the players first.');
      return;
    }

    let updated = 0;
    for (const v of valuations) {
      const recent = await this.prisma.playerGameweekScore.findMany({
        where: { playerId: v.playerId },
        orderBy: { updatedAt: 'desc' },
        take: PRICING.formWindow,
        select: { totalPoints: true },
      });
      const avgForm = recent.length
        ? recent.reduce((s, r) => s + r.totalPoints, 0) / recent.length
        : 0;

      const floor = PRICING.floorByPosition[v.position];
      const teamBoost = this._teamBoost(v.player.team.competition?.id);
      const playerBoost = this._playerBoost(v.player.id, v.player.shirtNumber);
      const formBoost = Math.max(0, Math.min(PRICING.formBoostMax, avgForm * PRICING.formWeight));

      const next = Math.max(
        PRICING.minPrice,
        Math.min(PRICING.maxPrice, floor + teamBoost + playerBoost + formBoost),
      );

      await this.prisma.playerValuation.update({
        where: { id: v.id },
        data: { recentForm: avgForm, price: Number(next.toFixed(1)) },
      });
      updated++;
    }
    this.log.log(`Repriced ${updated} players`);
  }

  // ─── Boosts ──────────────────────────────────────────────────────────────

  private _teamBoost(competitionId: string | null | undefined): number {
    return TEAM_BOOST_BY_COMPETITION[competitionId ?? ''] ?? 2;
  }

  /// Stable per-player variance. Uses FNV-1a over the player id to map
  /// every player to a value in [0, playerBoostMax]. We add a small bump
  /// for low shirt numbers (1-11) — those almost always indicate a senior
  /// / starting-XI player in international squads.
  private _playerBoost(playerId: string, shirtNumber: number | null): number {
    let h = 0x811c9dc5;
    for (let i = 0; i < playerId.length; i++) {
      h ^= playerId.charCodeAt(i);
      h = Math.imul(h, 0x01000193) >>> 0;
    }
    const base = ((h % 1000) / 1000) * PRICING.playerBoostMax;
    const shirtNudge = shirtNumber != null && shirtNumber >= 1 && shirtNumber <= 11 ? 1.5 : 0;
    return Math.min(PRICING.playerBoostMax, base + shirtNudge);
  }

  /// Exposed for testing — every Position should land on the expected
  /// floor with zero boosts.
  static floor(p: PlayerPosition): number {
    return PRICING.floorByPosition[p];
  }
}
