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
      // formBoost priority order:
      //   1. PlayerGameweekScore rows — most accurate (real fantasy points).
      //   2. PlayerValuation.seasonRating — api-football season rating
      //      (set by `npm run ingest:form`). Only counted when the
      //      player actually played a meaningful number of games — see
      //      PRICING.minAppearancesForForm. Otherwise their rating is
      //      noise on a tiny sample.
      //   3. Nothing — only player/team/position boosts fire.
      let formBoost = 0;
      let recentFormForLog = 0;
      const recent = await this.prisma.playerGameweekScore.findMany({
        where: { playerId: v.playerId },
        orderBy: { updatedAt: 'desc' },
        take: PRICING.formWindow,
        select: { totalPoints: true },
      });
      if (recent.length) {
        const avgForm = recent.reduce((s, r) => s + r.totalPoints, 0) / recent.length;
        recentFormForLog = avgForm;
        formBoost = Math.max(0, Math.min(PRICING.formBoostMax, avgForm * PRICING.formWeight));
      } else if (
        v.seasonRating != null &&
        (v.seasonAppearances ?? 0) >= PRICING.minAppearancesForForm
      ) {
        // Map a 0..10 rating to 0..formBoostMax. Anchored at the realistic
        // 6.4 → 8.4 range so the gradient lands inside actual data
        // instead of squishing everyone into the lower band.
        const norm = Math.max(0, Math.min(1, (v.seasonRating - 6.4) / 2.0));
        formBoost = norm * PRICING.formBoostMax;
        recentFormForLog = v.seasonRating;
      }

      const floor = PRICING.floorByPosition[v.position];
      const teamBoost = this._teamBoost(v.player.team.competition?.id);
      const playerBoost = this._playerBoost(v.player.id, v.player.shirtNumber);
      const apps = v.seasonAppearances ?? 0;

      // Apply appearance-tier cap on top of the global maxPrice. A player
      // who barely featured can't price out next to a starter no matter
      // how strong their team or hash is.
      const tierCap = this._tierCap(floor, apps);
      const next = Math.max(
        PRICING.minPrice,
        Math.min(tierCap, floor + teamBoost + playerBoost + formBoost),
      );

      await this.prisma.playerValuation.update({
        where: { id: v.id },
        data: { recentForm: recentFormForLog, price: Number(next.toFixed(1)) },
      });
      updated++;
    }
    this.log.log(`Repriced ${updated} players`);
  }

  // ─── Boosts ──────────────────────────────────────────────────────────────

  private _teamBoost(competitionId: string | null | undefined): number {
    return TEAM_BOOST_BY_COMPETITION[competitionId ?? ''] ?? 1.5;
  }

  /// Hard ceiling driven by minutes played last season. Without this
  /// the previous repricer let fringe academy players price out alongside
  /// established starters because their team + hash boosts compounded
  /// over a small appearances sample.
  private _tierCap(floor: number, apps: number): number {
    const { benchwarmer, rotation } = PRICING.appearanceTierCap;
    if (apps < benchwarmer.maxApps) return Math.min(PRICING.maxPrice, floor + benchwarmer.capOver);
    if (apps < rotation.maxApps)    return Math.min(PRICING.maxPrice, floor + rotation.capOver);
    return PRICING.maxPrice;
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
