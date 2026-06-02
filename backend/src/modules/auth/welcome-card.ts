import { CardRarity, PrismaClient } from '@prisma/client';

/// Eligible welcome-card rarities. Equal probability per rarity (1/3 each)
/// — within a rarity, a uniformly random template is drawn.
const WELCOME_RARITIES: CardRarity[] = ['COMMON', 'UNCOMMON', 'RARE'];

/**
 * Mint a one-off "signup gift" card for a brand-new user.
 *
 * Strategy:
 *   1. Pick a rarity uniformly from {COMMON, UNCOMMON, RARE}.
 *   2. Pick a random template within that rarity. Ones close to their cap
 *      (mintedCount ≥ totalSupply) are excluded.
 *   3. Increment the template's `mintedCount` and create an `OwnedCard` with
 *      `acquiredVia: SIGNUP_GIFT` in a single transaction.
 *
 * Returns the created OwnedCard's id, or `null` if the catalogue is empty
 * (e.g. seed:cards hasn't been run yet — never throws so signup keeps working
 * even before the cards are seeded).
 *
 * Performance: 2 queries on average — `count` for the rarity bucket then a
 * single `OFFSET random` lookup. Skips an O(N) full scan of the templates.
 */
export async function mintWelcomeCard(
  prisma: PrismaClient,
  userId: string,
): Promise<string | null> {
  // Try each rarity in random order so we don't fail hard if one bucket is
  // empty (e.g. only Common templates seeded yet).
  const order = shuffle([...WELCOME_RARITIES]);

  for (const rarity of order) {
    // Only real player cards (non-empty artUrl) so the signup gift is never
    // a blank placeholder template.
    const where = {
      rarity,
      artUrl: { not: '' },
      mintedCount: { lt: prisma.cardTemplate.fields.totalSupply },
    };
    const total = await prisma.cardTemplate.count({ where });
    if (total === 0) continue;

    const skip = Math.floor(Math.random() * total);
    const tmpl = await prisma.cardTemplate.findFirst({
      where,
      skip,
      select: { id: true, mintedCount: true },
    });
    if (!tmpl) continue;

    // Atomically reserve the next serial number for this template + create
    // the owned card. If two concurrent signups draw the same template, the
    // outer caller can retry — but the OwnedCard PK is a cuid so there's no
    // unique-constraint collision; the worst case is a duplicate
    // `serialNumber` for the same templateId, which `@@unique` rejects with
    // P2002 → we catch + re-pick.
    try {
      const created = await prisma.$transaction(async (tx) => {
        const updated = await tx.cardTemplate.update({
          where: { id: tmpl.id },
          data: { mintedCount: { increment: 1 } },
          select: { mintedCount: true },
        });
        return tx.ownedCard.create({
          data: {
            templateId: tmpl.id,
            serialNumber: updated.mintedCount,
            ownerId: userId,
            firstOwnerId: userId,
            acquiredVia: 'SIGNUP_GIFT',
          },
          select: { id: true },
        });
      });
      return created.id;
    } catch {
      // Race / cap reached mid-transaction — try the next rarity.
      continue;
    }
  }

  return null;
}

function shuffle<T>(arr: T[]): T[] {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}
