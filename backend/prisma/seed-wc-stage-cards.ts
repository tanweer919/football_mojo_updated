/**
 * WC 2026 stage-locked card editions.
 *
 * Builds five purchasable, time-windowed editions tied to the WC schedule:
 *
 *   Edition              Opens               Closes             Tier supply
 *   WC2026-GROUP         2026-06-11 00:00Z   2026-06-26 00:00Z   wide
 *   WC2026-R32           2026-06-25 00:00Z   2026-07-03 00:00Z   narrower
 *   WC2026-R16           2026-07-02 00:00Z   2026-07-08 00:00Z   narrower
 *   WC2026-QF            2026-07-07 00:00Z   2026-07-12 00:00Z   tight
 *   WC2026-SF            2026-07-11 00:00Z   2026-07-15 00:00Z   tight
 *   WC2026-FINAL         2026-07-14 00:00Z   2026-07-20 00:00Z   1-of-1 icons only
 *
 * For every BASE template that already exists (from `seed:cards`), this
 * script creates a matching stage edition with:
 *   - same playerId + rarity + baseStats
 *   - lower totalSupply (stage-scarcer)
 *   - dropOpensAt / dropClosesAt set per the table above
 *   - maxPerUser = 1 (so the Iconic stage card is one-per-account)
 *   - purchasable = true with rarity-scaled gemPrice
 *
 * Run AFTER `npm run seed:cards`. Idempotent — re-running updates in place.
 *
 * Usage:
 *   npm run seed:wc-stages
 */

import { CardRarity, Prisma, PrismaClient } from '@prisma/client';
import 'dotenv/config';

const prisma = new PrismaClient();

interface StageDef {
  edition: string;
  label: string;
  opensAt: Date;
  closesAt: Date;
  // Supply ceiling per rarity. The lower of (base supply, ceiling) is used.
  supplyCeilingByRarity: Partial<Record<CardRarity, number>>;
  // Per-rarity gem price. Iconic + Legendary always priced; lower tiers
  // can be omitted (template just won't be purchasable for that rarity).
  gemPriceByRarity: Partial<Record<CardRarity, number>>;
}

const STAGES: StageDef[] = [
  {
    edition: 'WC2026-GROUP',
    label: 'Group Stage',
    opensAt:  new Date(Date.UTC(2026, 5, 11)),  // 11 Jun 2026
    closesAt: new Date(Date.UTC(2026, 5, 26)),  // 26 Jun 2026
    supplyCeilingByRarity: {
      ICONIC:    1,
      LEGENDARY: 4,
      EPIC:      40,
      RARE:      200,
      UNCOMMON:  800,
      COMMON:    5000,
    },
    gemPriceByRarity: {
      ICONIC:    8000,
      LEGENDARY: 2500,
      EPIC:      700,
      RARE:      200,
    },
  },
  {
    edition: 'WC2026-R32',
    label: 'Round of 32',
    opensAt:  new Date(Date.UTC(2026, 5, 25)),
    closesAt: new Date(Date.UTC(2026, 6, 3)),
    supplyCeilingByRarity: {
      ICONIC:    1,
      LEGENDARY: 3,
      EPIC:      24,
      RARE:      120,
      UNCOMMON:  500,
    },
    gemPriceByRarity: {
      ICONIC:    9000,
      LEGENDARY: 3000,
      EPIC:      900,
      RARE:      280,
    },
  },
  {
    edition: 'WC2026-R16',
    label: 'Round of 16',
    opensAt:  new Date(Date.UTC(2026, 6, 2)),
    closesAt: new Date(Date.UTC(2026, 6, 8)),
    supplyCeilingByRarity: {
      ICONIC:    1,
      LEGENDARY: 2,
      EPIC:      16,
      RARE:      80,
    },
    gemPriceByRarity: {
      ICONIC:    10_000,
      LEGENDARY: 3500,
      EPIC:      1200,
      RARE:      400,
    },
  },
  {
    edition: 'WC2026-QF',
    label: 'Quarter-finals',
    opensAt:  new Date(Date.UTC(2026, 6, 7)),
    closesAt: new Date(Date.UTC(2026, 6, 12)),
    supplyCeilingByRarity: {
      ICONIC:    1,
      LEGENDARY: 2,
      EPIC:      10,
    },
    gemPriceByRarity: {
      ICONIC:    12_000,
      LEGENDARY: 4500,
      EPIC:      1600,
    },
  },
  {
    edition: 'WC2026-SF',
    label: 'Semi-finals',
    opensAt:  new Date(Date.UTC(2026, 6, 11)),
    closesAt: new Date(Date.UTC(2026, 6, 15)),
    supplyCeilingByRarity: {
      ICONIC:    1,
      LEGENDARY: 1,
      EPIC:      6,
    },
    gemPriceByRarity: {
      ICONIC:    15_000,
      LEGENDARY: 5500,
      EPIC:      2200,
    },
  },
  {
    edition: 'WC2026-FINAL',
    label: 'Final',
    opensAt:  new Date(Date.UTC(2026, 6, 14)),
    closesAt: new Date(Date.UTC(2026, 6, 20)),
    // The final edition is iconic-only. Everyone else's "Final" card is
    // earned via global cup placement, not bought.
    supplyCeilingByRarity: {
      ICONIC: 1,
    },
    gemPriceByRarity: {
      ICONIC: 25_000,
    },
  },
];

async function run() {
  console.log('Seeding WC 2026 stage-locked card editions…');

  // Source set: every BASE template we already created. We mirror the
  // playerId + rarity from there, then apply stage-specific caps.
  const baseTemplates = await prisma.cardTemplate.findMany({
    where: { edition: 'WC2026-BASE' },
    select: {
      id: true,
      playerId: true,
      rarity: true,
      baseStats: true,
      artUrl: true,
      totalSupply: true,
    },
  });
  console.log(`  ${baseTemplates.length} base templates to mirror`);

  if (!baseTemplates.length) {
    console.log('  No base templates found — run `npm run seed:cards` first.');
    return;
  }

  let totalUpserts = 0;
  const perStage: Record<string, { templates: number; minted?: number }> = {};

  for (const stage of STAGES) {
    let stageUpserts = 0;
    for (const base of baseTemplates) {
      const ceiling = stage.supplyCeilingByRarity[base.rarity];
      const price = stage.gemPriceByRarity[base.rarity];
      // Tier not represented in this stage's catalog → skip silently.
      // (We don't want common stage cards in the final, for example.)
      if (ceiling == null || price == null) continue;

      const stageSupply = Math.min(ceiling, base.totalSupply);
      const templateId = `${stage.edition}-${base.playerId}`;

      await prisma.cardTemplate.upsert({
        where: { id: templateId },
        create: {
          id: templateId,
          playerId: base.playerId,
          edition: stage.edition,
          rarity: base.rarity,
          totalSupply: stageSupply,
          // `baseStats` is `Json` on CardTemplate; the source row was already
          // validated by `seed:cards` so it's safe to forward as-is.
          baseStats: base.baseStats as Prisma.InputJsonValue,
          artUrl: base.artUrl,
          frameStyle: base.rarity === 'ICONIC' ? 'trophy' : 'holographic',
          // Stage editions are explicitly tradeable + buyable — that's the
          // whole point of them.
          giftableOnly: false,
          purchasable: true,
          gemPrice: price,
          dropOpensAt: stage.opensAt,
          dropClosesAt: stage.closesAt,
          // Per-user cap so the same account can't hoard the entire run.
          // Iconic = 1 by definition; everything else: 2.
          maxPerUser: base.rarity === 'ICONIC' ? 1 : 2,
        },
        update: {
          rarity: base.rarity,
          totalSupply: stageSupply,
          artUrl: base.artUrl,
          frameStyle: base.rarity === 'ICONIC' ? 'trophy' : 'holographic',
          giftableOnly: false,
          purchasable: true,
          gemPrice: price,
          dropOpensAt: stage.opensAt,
          dropClosesAt: stage.closesAt,
          maxPerUser: base.rarity === 'ICONIC' ? 1 : 2,
        },
      });
      stageUpserts++;
    }
    perStage[stage.label] = { templates: stageUpserts };
    totalUpserts += stageUpserts;
    console.log(`  ${stage.label.padEnd(16)} → ${stageUpserts} templates`);
  }

  console.log(`Done. ${totalUpserts} stage templates upserted across ${STAGES.length} editions.`);
}

run()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
