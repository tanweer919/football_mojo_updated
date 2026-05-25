/**
 * Card-template mint for every WC 2026 player.
 *
 * For each player attached to a WC 2026 team that already has a `photoUrl`:
 *   - Compute a deterministic rating (60–95) from a hash of the player id.
 *     This stays stable across re-runs so a card's rating doesn't change.
 *   - Bucket into a rarity tier:
 *       95+   → ICONIC      (1/1)
 *       90-94 → LEGENDARY   (5)
 *       86-89 → EPIC        (50)
 *       82-85 → RARE        (250)
 *       77-81 → UNCOMMON    (1,000)
 *       <77   → COMMON      (10,000)
 *   - Upsert exactly one CardTemplate per player per edition (`WC2026-BASE`).
 *
 * Players without `photoUrl` are skipped so we never mint a card with a
 * broken portrait — covers some lower-league call-ups api-football hasn't
 * shot yet.
 *
 * Idempotent. Re-run after `seed:roster` has populated the squad photos.
 *
 * Run: `npm run seed:cards`
 */

import { CardRarity, PrismaClient } from '@prisma/client';
import 'dotenv/config';

const prisma = new PrismaClient();

const COMPETITION_ID = 'WC2026';
const EDITION = 'WC2026-BASE';

interface RarityTier {
  rarity: CardRarity;
  totalSupply: number;
  /// True when only specific top players get this tier (no auto-promotion).
  manualOnly?: boolean;
}

const TIERS: Array<{ minRating: number; tier: RarityTier }> = [
  // Iconic is rare + manually elevated. The auto-rating mostly maxes at 94 so
  // ICONIC stays scarce — it gets explicitly assigned to the top 10 players
  // by `recentForm` (or `price`) below.
  { minRating: 95, tier: { rarity: 'ICONIC',    totalSupply: 1     } },
  { minRating: 90, tier: { rarity: 'LEGENDARY', totalSupply: 5     } },
  { minRating: 86, tier: { rarity: 'EPIC',      totalSupply: 50    } },
  { minRating: 82, tier: { rarity: 'RARE',      totalSupply: 250   } },
  { minRating: 77, tier: { rarity: 'UNCOMMON',  totalSupply: 1000  } },
  { minRating: 0,  tier: { rarity: 'COMMON',    totalSupply: 10000 } },
];

/**
 * Stable pseudo-random rating in [60, 94]. Uses FNV-1a 32-bit hash on the
 * player id so the same player always gets the same rating across re-runs.
 * (Top 10 by recent form are upgraded to 95 / ICONIC outside this function.)
 */
function ratingForPlayerId(id: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < id.length; i++) {
    h ^= id.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  // Map [0, 0xffffffff] → [60, 94].
  const norm = (h >>> 0) / 0xffffffff;
  // Skew slightly toward the middle (so most players land in 75–88 like the
  // real-world distribution).
  const skewed = Math.pow(norm, 0.85);
  return Math.round(60 + skewed * 34);
}

function tierFor(rating: number): RarityTier {
  for (const { minRating, tier } of TIERS) {
    if (rating >= minRating) return tier;
  }
  return TIERS[TIERS.length - 1].tier;
}

interface PlayerRow {
  id: string;
  name: string;
  position: string | null;
  photoUrl: string | null;
  team: { id: string; name: string };
  valuation: { recentForm: number; price: number } | null;
}

async function loadWcPlayers(): Promise<PlayerRow[]> {
  // Players whose team is bound to the WC competition.
  return prisma.player.findMany({
    where: {
      team: { competitionId: COMPETITION_ID },
      photoUrl: { not: null },
    },
    select: {
      id: true,
      name: true,
      position: true,
      photoUrl: true,
      team: { select: { id: true, name: true } },
      valuation: { select: { recentForm: true, price: true } },
    },
  });
}

async function run() {
  console.log(`Minting card templates for WC ${COMPETITION_ID} squad…`);
  const players = await loadWcPlayers();
  console.log(`  ${players.length} players with photos`);

  if (players.length === 0) {
    console.log('  no eligible players — run `npm run seed:roster` first.');
    return;
  }

  // Promote the top-10 by (recentForm desc, price desc) to ICONIC. These are
  // the marquee names that justify a 1-of-1.
  const ranked = [...players].sort((a, b) => {
    const fa = a.valuation?.recentForm ?? 0;
    const fb = b.valuation?.recentForm ?? 0;
    if (fa !== fb) return fb - fa;
    const pa = a.valuation?.price ?? 0;
    const pb = b.valuation?.price ?? 0;
    return pb - pa;
  });
  const iconicSet = new Set(ranked.slice(0, 10).map((p) => p.id));

  let upserts = 0;
  let perTier: Record<string, number> = {};

  for (const p of players) {
    if (!p.photoUrl) continue;
    const baseRating = iconicSet.has(p.id) ? 95 : ratingForPlayerId(p.id);
    const tier = tierFor(baseRating);

    // baseStats is a Json column on CardTemplate — synthetic numbers derived
    // from rating so the card art has something meaningful to render.
    const baseStats = synthesizeStats(baseRating, p.position);

    // One template per player per edition. ID is deterministic so re-runs
    // update in place (e.g. art URL changed because the headshot was updated).
    const templateId = `WC2026-BASE-${p.id}`;
    await prisma.cardTemplate.upsert({
      where: { id: templateId },
      create: {
        id: templateId,
        playerId: p.id,
        edition: EDITION,
        rarity: tier.rarity,
        totalSupply: tier.totalSupply,
        baseStats,
        artUrl: p.photoUrl,
        frameStyle: tier.rarity === 'ICONIC' ? 'trophy' : 'base',
        purchasable: false,
        giftableOnly: tier.rarity === 'ICONIC',
      },
      update: {
        playerId: p.id,
        rarity: tier.rarity,
        totalSupply: tier.totalSupply,
        baseStats,
        artUrl: p.photoUrl,
      },
    });
    upserts++;
    perTier[tier.rarity] = (perTier[tier.rarity] ?? 0) + 1;
  }

  console.log(`\n✓ minted ${upserts} card templates`);
  for (const [tier, n] of Object.entries(perTier).sort()) {
    console.log(`  ${tier.padEnd(10)} ${n}`);
  }
}

/**
 * Position-aware synthetic FIFA-style attribute block. Goalkeepers get high
 * defending + low attacking, forwards get inverse, etc. Real on-pitch stats
 * roll up from match data — these are just for cosmetic display.
 */
function synthesizeStats(rating: number, position: string | null) {
  const r = rating;
  const noisy = (base: number, jitter: number) =>
    Math.max(40, Math.min(99, Math.round(base + (Math.random() * 2 - 1) * jitter)));
  switch ((position ?? '').toUpperCase()) {
    case 'GK':
      return { pace: noisy(r - 12, 5), shot: noisy(r - 25, 4), pass: noisy(r - 5, 5), dribble: noisy(r - 18, 5), defence: noisy(r + 4, 4), physical: noisy(r + 2, 4) };
    case 'DEF':
      return { pace: noisy(r - 4, 6), shot: noisy(r - 14, 6), pass: noisy(r - 2, 5), dribble: noisy(r - 8, 6), defence: noisy(r + 4, 4), physical: noisy(r + 3, 4) };
    case 'MID':
      return { pace: noisy(r - 1, 5), shot: noisy(r - 4, 5), pass: noisy(r + 3, 4), dribble: noisy(r + 1, 5), defence: noisy(r - 5, 6), physical: noisy(r, 5) };
    case 'FWD':
      return { pace: noisy(r + 4, 4), shot: noisy(r + 4, 4), pass: noisy(r - 4, 5), dribble: noisy(r + 3, 4), defence: noisy(r - 18, 6), physical: noisy(r - 1, 5) };
    default:
      return { pace: r, shot: r, pass: r, dribble: r, defence: r, physical: r };
  }
}

run()
  .catch((err) => {
    console.error('seed-wc-cards failed:', err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
