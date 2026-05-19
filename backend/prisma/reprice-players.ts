/**
 * One-shot CLI to run the fantasy player repricer outside the daily 3 AM
 * cron. Useful after:
 *   - Seeding a new competition (gives every fresh PlayerValuation a real
 *     spread instead of leaving everyone at `defaultPrice = 14.0`).
 *   - Tuning the pricing constants below and wanting the new model live
 *     without waiting overnight.
 *   - Importing a batch of historical `PlayerGameweekScore` rows.
 *
 * Run:
 *   npm run reprice:players
 *   docker compose exec api npm run reprice:players
 *
 * Self-contained — does NOT import from `src/`. The runtime container
 * only ships `dist/`, so a `from '../src/...'` import fails with
 * MODULE_NOT_FOUND there. The pricing logic is intentionally duplicated
 * here; keep it in sync with `src/modules/fantasy/pricing.service.ts` +
 * `src/modules/fantasy/fantasy.constants.ts`. Both are short and rarely
 * change.
 */

import { PlayerPosition, PrismaClient } from '@prisma/client';
import 'dotenv/config';

const prisma = new PrismaClient();

// Mirrors PRICING + TEAM_BOOST_BY_COMPETITION in fantasy.constants.ts.
const PRICING = {
  minPrice: 4.0,
  maxPrice: 26.0,
  floorByPosition: { GK: 10, DEF: 11, MID: 12, FWD: 13 } as Record<PlayerPosition, number>,
  playerBoostMax: 6,
  formBoostMax: 8,
  formWindow: 5,
  formWeight: 0.5,
};

const TEAM_BOOST_BY_COMPETITION: Record<string, number> = {
  WC2026: 6.0,
  PREMIER_LEAGUE: 6.0,
  LA_LIGA: 5.5,
  BUNDESLIGA: 5.0,
  SERIE_A: 5.0,
  LIGUE_1: 4.5,
  UCL: 6.0,
  UEL: 4.0,
  EUROPA_CONFERENCE: 3.0,
};

function teamBoost(competitionId: string | null | undefined): number {
  return TEAM_BOOST_BY_COMPETITION[competitionId ?? ''] ?? 2;
}

/// Stable per-player variance via FNV-1a over the player id.
function playerBoost(playerId: string, shirtNumber: number | null): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < playerId.length; i++) {
    h ^= playerId.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  const base = ((h % 1000) / 1000) * PRICING.playerBoostMax;
  const shirtNudge = shirtNumber != null && shirtNumber >= 1 && shirtNumber <= 11 ? 1.5 : 0;
  return Math.min(PRICING.playerBoostMax, base + shirtNudge);
}

async function main() {
  const valuations = await prisma.playerValuation.findMany({
    include: {
      player: { include: { team: { include: { competition: { select: { id: true } } } } } },
    },
  });
  if (!valuations.length) {
    console.warn('[reprice] No player valuations to reprice — seed the players first.');
    return;
  }

  let updated = 0;
  for (const v of valuations) {
    const recent = await prisma.playerGameweekScore.findMany({
      where: { playerId: v.playerId },
      orderBy: { updatedAt: 'desc' },
      take: PRICING.formWindow,
      select: { totalPoints: true },
    });
    const avgForm = recent.length
      ? recent.reduce((s, r) => s + r.totalPoints, 0) / recent.length
      : 0;

    const floor = PRICING.floorByPosition[v.position];
    const tb = teamBoost(v.player.team.competition?.id);
    const pb = playerBoost(v.player.id, v.player.shirtNumber);
    const fb = Math.max(0, Math.min(PRICING.formBoostMax, avgForm * PRICING.formWeight));

    const next = Math.max(
      PRICING.minPrice,
      Math.min(PRICING.maxPrice, floor + tb + pb + fb),
    );

    await prisma.playerValuation.update({
      where: { id: v.id },
      data: { recentForm: avgForm, price: Number(next.toFixed(1)) },
    });
    updated++;
  }
  console.log(`[reprice] Repriced ${updated} players.`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
