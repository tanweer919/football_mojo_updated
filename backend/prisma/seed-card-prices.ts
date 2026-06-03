/**
 * Gem pricing + starter bundles.
 *
 * Two jobs, both idempotent:
 *
 *  1. PRICE the direct store. Marks every real player-card template
 *     (non-empty art, COMMON..LEGENDARY) `purchasable` and sets its
 *     `gemPrice` from CARD_GEM_PRICES. ICONIC + giftable-only templates are
 *     left unpurchasable on purpose — they're earned/airdropped, never bought.
 *
 *  2. BUILD a few transparent bundles ("packs" with KNOWN contents). Each is
 *     a fixed list of cards sold for slightly less than buying them singly
 *     (BUNDLE_DISCOUNT). Members are picked deterministically (cheapest /
 *     most-available first) so re-runs reproduce the same bundle.
 *
 * Prices are intentionally a touch high vs the gem earn-rate so the FREE
 * rewarded-ad card stays worthwhile — gems buy the SPECIFIC card you want.
 *
 * Run AFTER `seed:cards`:  `npm run seed:prices`
 */

import { CardRarity, PrismaClient } from '@prisma/client';
import 'dotenv/config';
import { CARD_GEM_PRICES, BUNDLE_DISCOUNT } from '../src/modules/cards/cards.pricing';

const prisma = new PrismaClient();

// Rarities we sell singly + bundle. ICONIC excluded (null price → premium).
const SELLABLE: CardRarity[] = ['COMMON', 'UNCOMMON', 'RARE', 'EPIC', 'LEGENDARY'];

/** Bundle recipes: each picks N member cards by rarity from the priced pool.
 *  Contents are fixed once seeded (deterministic ordering), so the buyer
 *  always sees the same transparent list. */
const BUNDLE_RECIPES: Array<{
  name: string;
  description: string;
  sortOrder: number;
  picks: CardRarity[];
}> = [
  {
    name: 'Rising Stars',
    description: 'Three in-form squad players to kick off your collection.',
    sortOrder: 1,
    picks: ['UNCOMMON', 'UNCOMMON', 'RARE'],
  },
  {
    name: 'Match Winners',
    description: 'Difference-makers — a rare core plus a wildcard.',
    sortOrder: 2,
    picks: ['RARE', 'RARE', 'EPIC'],
  },
  {
    name: 'Galácticos',
    description: 'A marquee epic flanked by two rares. The headline pack.',
    sortOrder: 3,
    picks: ['EPIC', 'RARE', 'RARE'],
  },
];

function gemPrice(rarity: CardRarity): number {
  return CARD_GEM_PRICES[rarity] ?? 0;
}

async function priceSingles(): Promise<number> {
  let total = 0;
  for (const rarity of SELLABLE) {
    const price = gemPrice(rarity);
    if (!price) continue;
    const res = await prisma.cardTemplate.updateMany({
      where: {
        rarity,
        artUrl: { not: '' },
        giftableOnly: false,
      },
      data: { purchasable: true, gemPrice: price },
    });
    total += res.count;
    console.log(`  ${rarity.padEnd(10)} → ${price}💎  (${res.count} templates)`);
  }
  return total;
}

/** Pick `n` purchasable templates of a rarity the bundle hasn't used yet.
 *  Ordered by most-available then id so the choice is stable + in stock. */
async function pickTemplates(
  rarity: CardRarity,
  n: number,
  exclude: Set<string>,
): Promise<string[]> {
  const rows = await prisma.cardTemplate.findMany({
    where: { rarity, purchasable: true, artUrl: { not: '' } },
    orderBy: [{ id: 'asc' }],
    select: { id: true, mintedCount: true, totalSupply: true },
  });
  const available = rows
    .filter((r) => !exclude.has(r.id) && r.mintedCount < r.totalSupply)
    .slice(0, n);
  return available.map((r) => r.id);
}

async function buildBundles() {
  for (const recipe of BUNDLE_RECIPES) {
    const used = new Set<string>();
    const templateIds: string[] = [];
    for (const rarity of recipe.picks) {
      const got = await pickTemplates(rarity, 1, used);
      if (!got.length) {
        console.warn(`  ⚠ "${recipe.name}": no available ${rarity} template — skipping member`);
        continue;
      }
      templateIds.push(got[0]!);
      used.add(got[0]!);
    }
    if (templateIds.length < 2) {
      console.warn(`  ⚠ "${recipe.name}": too few members (${templateIds.length}) — skipped`);
      continue;
    }

    const tpls = await prisma.cardTemplate.findMany({
      where: { id: { in: templateIds } },
      select: { rarity: true },
    });
    const singleTotal = tpls.reduce((s, t) => s + gemPrice(t.rarity), 0);
    const bundlePrice = Math.round((singleTotal * BUNDLE_DISCOUNT) / 5) * 5; // round to 5

    // Idempotent: wipe + recreate the bundle of this name so re-runs refresh
    // contents/price cleanly (CardBundleEntry cascades on bundle delete).
    await prisma.cardBundle.deleteMany({ where: { name: recipe.name } });
    await prisma.cardBundle.create({
      data: {
        name: recipe.name,
        description: recipe.description,
        gemPrice: bundlePrice,
        active: true,
        sortOrder: recipe.sortOrder,
        entries: { create: templateIds.map((templateId) => ({ templateId })) },
      },
    });
    console.log(
      `  "${recipe.name}": ${templateIds.length} cards · ${bundlePrice}💎 (save ${singleTotal - bundlePrice} vs ${singleTotal})`,
    );
  }
}

async function run() {
  console.log('Pricing single cards…');
  const priced = await priceSingles();
  console.log(`Priced ${priced} templates.\n`);

  console.log('Building bundles…');
  await buildBundles();
  console.log('\nDone.');
}

run()
  .catch((err) => {
    console.error('seed-card-prices failed:', err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
