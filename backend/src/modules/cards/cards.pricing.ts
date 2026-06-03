import { CardRarity } from '@prisma/client';

// Gem pricing — kept dependency-free (no NestJS) so the `seed:prices` script
// can import it without dragging in the whole service graph.

/// Gem price per rarity for DIRECT purchase + bundle pricing. Deliberately
/// set "slightly expensive" relative to the gem earn-rate so the FREE
/// rewarded-ad card (a random UNCOMMON/RARE/EPIC) stays the obvious budget
/// path — gems are for buying the SPECIFIC card you want, not the cheapest
/// way to fill the album. ICONIC stays null: premium tier is earned/airdropped
/// only, never gem-purchasable. Tune here — `seed:prices` reads these.
export const CARD_GEM_PRICES: Record<CardRarity, number | null> = {
  COMMON: 60,
  UNCOMMON: 120,
  RARE: 250,
  EPIC: 500,
  LEGENDARY: 1000,
  ICONIC: null,
};

/// Bundles cost this fraction of the sum of their members' single prices —
/// a slight (15% off) "buy the set together" discount, not a deep cut.
export const BUNDLE_DISCOUNT = 0.85;

/// Gem price for a single card of `rarity`, or null when it's not
/// gem-purchasable (ICONIC).
export function cardGemPrice(rarity: CardRarity): number | null {
  return CARD_GEM_PRICES[rarity] ?? null;
}
