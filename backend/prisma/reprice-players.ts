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
// Keep in sync — Docker container doesn't ship src/, so we duplicate.
const PRICING = {
  minPrice: 4.0,
  maxPrice: 26.0,
  floorByPosition: { GK: 8, DEF: 9, MID: 10, FWD: 11 } as Record<PlayerPosition, number>,
  playerBoostMax: 6,
  formBoostMax: 8,
  formWindow: 5,
  formWeight: 0.5,
  minAppearancesForForm: 5,
  appearanceTierCap: {
    benchwarmer: { maxApps: 5,  capOver: 4 },
    rotation:    { maxApps: 15, capOver: 7 },
  },
};

const TEAM_BOOST_BY_COMPETITION: Record<string, number> = {
  WC2026: 4.0,
  PREMIER_LEAGUE: 4.0,
  LA_LIGA: 3.8,
  BUNDESLIGA: 3.5,
  SERIE_A: 3.5,
  LIGUE_1: 3.0,
  UCL: 4.0,
  UEL: 2.5,
  EUROPA_CONFERENCE: 1.8,
};

function teamBoost(competitionId: string | null | undefined): number {
  return TEAM_BOOST_BY_COMPETITION[competitionId ?? ''] ?? 1.5;
}

function tierCap(floor: number, apps: number): number {
  const { benchwarmer, rotation } = PRICING.appearanceTierCap;
  if (apps < benchwarmer.maxApps) return Math.min(PRICING.maxPrice, floor + benchwarmer.capOver);
  if (apps < rotation.maxApps)    return Math.min(PRICING.maxPrice, floor + rotation.capOver);
  return PRICING.maxPrice;
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
    // Mirror the priority order in `pricing.service.ts`:
    //   1. PlayerGameweekScore — real fantasy points (best).
    //   2. PlayerValuation.seasonRating — api-football 0..10 (bridge).
    //   3. Nothing (formBoost = 0).
    let fb = 0;
    let recentFormForLog = 0;
    const recent = await prisma.playerGameweekScore.findMany({
      where: { playerId: v.playerId },
      orderBy: { updatedAt: 'desc' },
      take: PRICING.formWindow,
      select: { totalPoints: true },
    });
    if (recent.length) {
      const avg = recent.reduce((s, r) => s + r.totalPoints, 0) / recent.length;
      recentFormForLog = avg;
      fb = Math.max(0, Math.min(PRICING.formBoostMax, avg * PRICING.formWeight));
    } else if (
      v.seasonRating != null &&
      (v.seasonAppearances ?? 0) >= PRICING.minAppearancesForForm
    ) {
      // Only respect a season rating when the sample is meaningful —
      // a 2-game cameo at 8.0 isn't form, it's noise.
      const norm = Math.max(0, Math.min(1, (v.seasonRating - 6.4) / 2.0));
      fb = norm * PRICING.formBoostMax;
      recentFormForLog = v.seasonRating;
    }

    const floor = PRICING.floorByPosition[v.position];
    const tb = teamBoost(v.player.team.competition?.id);
    const pb = playerBoost(v.player.id, v.player.shirtNumber);
    const apps = v.seasonAppearances ?? 0;

    // Cap by appearances tier so squad fillers can't price out as starters.
    const cap = tierCap(floor, apps);
    const next = Math.max(
      PRICING.minPrice,
      Math.min(cap, floor + tb + pb + fb),
    );

    await prisma.playerValuation.update({
      where: { id: v.id },
      data: { recentForm: recentFormForLog, price: Number(next.toFixed(1)) },
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
