import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { AcquisitionSource, CardRarity, Prisma } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';
import { GemsService } from '../gems/gems.service';
import { MintingService } from './minting.service';
import { cardGemPrice } from './cards.pricing';

/// XP→level table. Doubling cadence keeps the curve interesting all the
/// way to 5 stars without making the top unreachable for an active user.
/// 200 XP per goal-equivalent (rough rule of thumb) → roughly 1 star per
/// 4 high-scoring matches the player features in.
const LEVEL_THRESHOLDS = [0, 200, 600, 1400, 3000, 6000];
export function levelFromXp(xp: number): number {
  for (let i = LEVEL_THRESHOLDS.length - 1; i >= 0; i--) {
    if (xp >= LEVEL_THRESHOLDS[i]) return i;
  }
  return 0;
}

function round1(n: number): number { return Math.round(n * 10) / 10; }

@Injectable()
export class CardsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly minting: MintingService,
    private readonly gems: GemsService,
  ) {}

  // ─── Album view ────────────────────────────────────────────────────────────
  // Returns the user's full sticker-album: every template grouped by set,
  // with owned-count + duplicate-count so the UI can show "owned / needed / dupes".
  // If there are owned cards whose templates aren't in any CardSet, they appear
  // in a synthetic "My Cards" set so the album is never empty when the user owns cards.
  async getAlbum(userId: string) {
    const [sets, owned] = await Promise.all([
      this.prisma.cardSet.findMany({
        include: { entries: { include: { template: { include: { player: { include: { team: true } } } } } } },
      }),
      this.prisma.ownedCard.findMany({
        where: { ownerId: userId },
        include: { template: { include: { player: { include: { team: true } } } } },
        orderBy: { mintedAt: 'asc' },
      }),
    ]);

    const ownedCount = new Map<string, number>();
    const firstOwnedByTemplate = new Map<string, string>();
    for (const o of owned) {
      ownedCount.set(o.templateId, (ownedCount.get(o.templateId) ?? 0) + 1);
      if (!firstOwnedByTemplate.has(o.templateId)) firstOwnedByTemplate.set(o.templateId, o.id);
    }

    // Template IDs that belong to at least one CardSet.
    const setTemplateIds = new Set(
      sets.flatMap((s) => s.entries.map((e) => e.templateId)),
    );

    // Flatten player/team data into the template object so the client gets
    // `playerName`, `teamName`, `teamCrestUrl` at the template level.
    const flattenTemplate = (t: any) => ({
      id: t.id,
      edition: t.edition,
      rarity: t.rarity,
      totalSupply: t.totalSupply,
      mintedCount: t.mintedCount,
      artUrl: t.artUrl,
      frameStyle: t.frameStyle,
      playerName: t.player?.name ?? null,
      teamName: t.player?.team?.name ?? null,
      teamCrestUrl: t.player?.team?.crestUrl ?? null,
      position: t.player?.position ?? null,
      // Scarcity surface — exposed so the client can render mint caps,
      // drop windows, and per-user caps in the album / market tiles.
      dropOpensAt:  t.dropOpensAt ?? null,
      dropClosesAt: t.dropClosesAt ?? null,
      maxPerUser:   t.maxPerUser ?? null,
    });

    const result = sets.map((s) => ({
      id: s.id,
      name: s.name,
      description: s.description,
      total: s.entries.length,
      completedCount: s.entries.filter((e) => (ownedCount.get(e.templateId) ?? 0) > 0).length,
      entries: s.entries.map((e) => ({
        templateId: e.templateId,
        template: flattenTemplate(e.template),
        owned: ownedCount.get(e.templateId) ?? 0,
        firstOwnedCardId: firstOwnedByTemplate.get(e.templateId) ?? null,
      })),
    }));

    // Collect owned cards not in any set into a virtual "My Cards" set.
    const uncategorized = owned.filter((o) => !setTemplateIds.has(o.templateId));
    if (uncategorized.length > 0) {
      // Deduplicate by templateId — show each template once.
      const seen = new Set<string>();
      const entries: Array<any> = [];
      for (const o of uncategorized) {
        if (seen.has(o.templateId)) continue;
        seen.add(o.templateId);
        entries.push({
          templateId: o.templateId,
          template: flattenTemplate(o.template),
          owned: ownedCount.get(o.templateId) ?? 0,
          firstOwnedCardId: firstOwnedByTemplate.get(o.templateId) ?? null,
        });
      }
      result.unshift({
        id: '__my_cards__',
        name: 'My Cards',
        description: 'Cards you own',
        total: entries.length,
        completedCount: entries.length,
        entries,
      });
    }

    return result;
  }

  async listOwned(userId: string) {
    return this.prisma.ownedCard.findMany({
      where: { ownerId: userId },
      include: { template: { include: { player: { include: { team: true } } } } },
      orderBy: { mintedAt: 'desc' },
    });
  }

  /**
   * Rich owned-card detail — feeds the Sorare-style detail screen.
   *
   * Returns:
   *   - the OwnedCard with its template + player + team
   *   - per-card progression (lifetime stats, XP/level, trophies)
   *   - mint context (`mintReason`, `acquiredVia`, `mintedAt`)
   *   - provenance: first owner display info
   *   - "last scores" — last N PlayerGameweekScore rows for the player,
   *     with goal/assist flags from MatchEvent so the UI can render the
   *     Sorare-style "performance bars" chart
   *   - sister copies the user owns of this template (so the detail
   *     screen can offer a "swap to your other copy" hint)
   */
  async getOwnedCard(userId: string, ownedCardId: string) {
    const card = await this.prisma.ownedCard.findFirst({
      where: { id: ownedCardId, ownerId: userId },
      include: {
        template: {
          include: {
            player: { include: { team: true } },
          },
        },
      },
    });
    if (!card) throw new NotFoundException('card_not_found');

    // Provenance — first-owner profile (display name + tag + avatar). May
    // be a tombstone admin shell row, in which case we surface tag.
    const firstOwner = await this.prisma.user.findUnique({
      where: { id: card.firstOwnerId },
      select: { id: true, displayName: true, userTag: true, photoUrl: true },
    });

    // Last N scores — drives the performance graph. We pull from
    // PlayerGameweekScore which is the per-(player, gameweek) row. Order
    // descending by the gameweek's deadline so most recent comes first
    // (UI will reverse for left-to-right chronology).
    const playerId = card.template.player?.id;
    const lastScores = playerId
      ? await this.prisma.playerGameweekScore.findMany({
          where: { playerId },
          orderBy: { updatedAt: 'desc' },
          take: 10,
          include: {
            gameweek: {
              select: { id: true, number: true, lockAt: true, tournamentId: true },
            },
          },
        })
      : [];

    // Last-5 / 10 / 40 averages — Sorare's signature "form" widget.
    const avg = (arr: number[]) => arr.length ? arr.reduce((s, x) => s + x, 0) / arr.length : 0;
    const last40 = playerId
      ? await this.prisma.playerGameweekScore.findMany({
          where: { playerId },
          orderBy: { updatedAt: 'desc' },
          take: 40,
          select: { totalPoints: true },
        })
      : [];
    const points40 = last40.map((s) => s.totalPoints);
    const formStats = {
      last5: { avg: round1(avg(points40.slice(0, 5))), n: Math.min(5, points40.length) },
      last10: { avg: round1(avg(points40.slice(0, 10))), n: Math.min(10, points40.length) },
      last40: { avg: round1(avg(points40)), n: points40.length },
    };

    // Sister copies the user owns of this template — surfaces in a
    // "your other copies" footer ("you also own #91, #133").
    const sisters = await this.prisma.ownedCard.findMany({
      where: {
        ownerId: userId,
        templateId: card.templateId,
        id: { not: card.id },
      },
      select: { id: true, serialNumber: true, mintedAt: true, xp: true },
      orderBy: { serialNumber: 'asc' },
      take: 12,
    });

    return {
      ...card,
      // Flatten the template the same way getAlbum/store do, so the client's
      // CardTemplateDto sees playerName/teamName/artUrl at the top level
      // (otherwise the detail screen shows "Player" and no art).
      template: {
        id: card.template.id,
        edition: card.template.edition,
        rarity: card.template.rarity,
        totalSupply: card.template.totalSupply,
        mintedCount: card.template.mintedCount,
        artUrl: card.template.artUrl,
        frameStyle: card.template.frameStyle,
        playerName: card.template.player?.name ?? null,
        teamName: card.template.player?.team?.name ?? null,
        teamCrestUrl: card.template.player?.team?.crestUrl ?? null,
        position: card.template.player?.position ?? null,
        dropOpensAt: card.template.dropOpensAt ?? null,
        dropClosesAt: card.template.dropClosesAt ?? null,
        maxPerUser: card.template.maxPerUser ?? null,
      },
      // Spread the level out from XP at render — keeps the DB column
      // honest as the source-of-truth XP value.
      level: levelFromXp(card.xp),
      firstOwner,
      lastScores: lastScores.map((s) => ({
        gameweekId: s.gameweekId,
        gameweekNumber: s.gameweek?.number ?? null,
        gameweekLockAt: s.gameweek?.lockAt ?? null,
        totalPoints: s.totalPoints,
        breakdown: s.breakdown,
        updatedAt: s.updatedAt,
      })),
      formStats,
      sisters,
    };
  }

  /// Pin a card to the user's profile showcase. Pass `null` to clear.
  /// Validates ownership server-side — the User.pinnedCardId FK doesn't
  /// enforce a "must be owned by this user" check, so we do it here.
  async setPinnedCard(userId: string, ownedCardId: string | null) {
    if (ownedCardId) {
      const card = await this.prisma.ownedCard.findFirst({
        where: { id: ownedCardId, ownerId: userId },
        select: { id: true },
      });
      if (!card) throw new NotFoundException('card_not_found');
    }
    await this.prisma.user.update({
      where: { id: userId },
      data: { pinnedCardId: ownedCardId },
    });
    return { pinnedCardId: ownedCardId };
  }

  // ─── Earning paths ─────────────────────────────────────────────────────────
  // All of these are deterministic with respect to money. No paid randomness.

  async claimDailyLogin(userId: string) {
    const today = new Date(); today.setUTCHours(0, 0, 0, 0);
    const existing = await this.prisma.ownedCard.findFirst({
      where: { ownerId: userId, acquiredVia: 'DAILY_LOGIN', mintedAt: { gte: today } },
    });
    if (existing) throw new BadRequestException('already_claimed_today');

    // Pre-curated daily rotation — every user gets the SAME card on a given UTC day.
    // Halal: deterministic, no chance element.
    const rotation = await this.prisma.cardTemplate.findMany({
      where: { edition: 'WC2026-DAILY', giftableOnly: true },
      orderBy: { id: 'asc' },
    });
    if (!rotation.length) throw new NotFoundException('no_daily_rotation');
    const idx = Math.floor(Date.now() / 86_400_000) % rotation.length;
    const tpl = rotation[idx]!;

    const card = await this.minting.award({ userId, templateId: tpl.id, source: 'DAILY_LOGIN' });
    // Return the enriched card (with flattened template) so the client can
    // parse + render it — minting.award returns a bare OwnedCard with no
    // template, which fails OwnedCardDto.fromJson.
    return this.getOwnedCard(userId, card.id);
  }

  // Rewarded-ad mint: user watches a ~30s ad, server validates the ad SSV
  // callback (signed token verified upstream) and mints a RANDOM card from
  // the "reward tier" — second-lowest rarity and up, never the bottom-most
  // COMMON tier (so the reward feels worthwhile) and never the premium
  // ICONIC/LEGENDARY tiers (those stay paid/earned). Capped per UTC day to
  // stop ad-farming.
  static readonly REWARDED_AD_TIERS: CardRarity[] = ['UNCOMMON', 'RARE', 'EPIC'];
  static readonly REWARDED_AD_DAILY_CAP = 10;

  /// How many free (rewarded-ad) cards the user can still claim today. Lets
  /// the client hide/disable the "watch ad" CTA once the cap is hit instead
  /// of making them sit through an ad only to be refused.
  async rewardedAdStatus(userId: string) {
    const dayStart = new Date();
    dayStart.setUTCHours(0, 0, 0, 0);
    const claimedToday = await this.prisma.ownedCard.count({
      where: { ownerId: userId, acquiredVia: 'REWARDED_AD', mintedAt: { gte: dayStart } },
    });
    const cap = CardsService.REWARDED_AD_DAILY_CAP;
    return { claimedToday, cap, remaining: Math.max(0, cap - claimedToday) };
  }

  async claimRewardedAd(userId: string) {
    // Per-day cap: count REWARDED_AD cards minted to this user since UTC midnight.
    const dayStart = new Date();
    dayStart.setUTCHours(0, 0, 0, 0);
    const claimedToday = await this.prisma.ownedCard.count({
      where: { ownerId: userId, acquiredVia: 'REWARDED_AD', mintedAt: { gte: dayStart } },
    });
    if (claimedToday >= CardsService.REWARDED_AD_DAILY_CAP) {
      throw new BadRequestException('rewarded_ad_daily_cap_reached');
    }

    // Walk the reward tiers from second-lowest up. Within the first tier
    // that still has a REAL player card (non-empty artUrl) the user is
    // MISSING, pick one at random. We require artUrl so the reward is never
    // a blank placeholder template, and we DON'T require giftableOnly —
    // those are only the ICONIC premium templates; the regular player
    // cards (which carry the art) are the right reward pool.
    for (const rarity of CardsService.REWARDED_AD_TIERS) {
      const missing = await this.prisma.$queryRaw<Array<{ id: string }>>(Prisma.sql`
        SELECT t.id FROM "CardTemplate" t
        WHERE t.rarity = ${rarity}::"CardRarity"
          AND t."artUrl" <> ''
          AND t."mintedCount" < t."totalSupply"
          -- Only cards we can actually mint right now: respect the drop window,
          -- else minting.award throws drop_closed/drop_not_open_yet (a 400 that
          -- looked like "reward failed"). Stage-locked editions have windows.
          AND (t."dropOpensAt" IS NULL OR t."dropOpensAt" <= NOW())
          AND (t."dropClosesAt" IS NULL OR t."dropClosesAt" > NOW())
          AND NOT EXISTS (
            SELECT 1 FROM "OwnedCard" o
            WHERE o."templateId" = t.id AND o."ownerId" = ${userId}
          )
        ORDER BY RANDOM()
        LIMIT 1;
      `);
      if (missing.length) {
        const card = await this.minting.award({ userId, templateId: missing[0]!.id, source: 'REWARDED_AD' });
        // Enriched card (flattened template) so the client parses + renders
        // it; the bare OwnedCard from minting.award has no template.
        return this.getOwnedCard(userId, card.id);
      }
    }
    throw new BadRequestException('reward_tier_album_complete');
  }

  // ─── Direct purchase (halal IAP) ──────────────────────────────────────────
  // User explicitly buys a NAMED card for a KNOWN gem price. No uncertainty.
  // Gem deduction goes through the GemsService ledger so every spend is
  // auditable and dedupe-protected.
  async purchaseCard(userId: string, templateId: string) {
    const tpl = await this.prisma.cardTemplate.findUnique({ where: { id: templateId } });
    if (!tpl) throw new NotFoundException('template_not_found');
    if (!tpl.purchasable || !tpl.gemPrice)
      throw new BadRequestException('not_purchasable');
    if (tpl.mintedCount >= tpl.totalSupply)
      throw new BadRequestException('sold_out');
    // Drop-window enforcement here mirrors MintingService.mint so the user
    // can't buy a template whose window hasn't opened yet.
    const now = new Date();
    if (tpl.dropOpensAt && tpl.dropOpensAt.getTime() > now.getTime())
      throw new BadRequestException('drop_not_open_yet');
    if (tpl.dropClosesAt && tpl.dropClosesAt.getTime() <= now.getTime())
      throw new BadRequestException('drop_closed');
    if (tpl.maxPerUser != null) {
      const owned = await this.prisma.ownedCard.count({
        where: { templateId, ownerId: userId },
      });
      if (owned >= tpl.maxPerUser)
        throw new BadRequestException('per_user_cap_reached');
    }

    // Debit through the ledger. Idempotent dedupe on (user, source, ref).
    // We use a per-purchase ref by combining templateId + the next serial
    // number — recorded inside the mint transaction below to keep them
    // both consistent. Since the serial isn't known yet, we use a unique
    // request-id-style ref (timestamp + templateId) so a flaky retry doesn't
    // re-debit on a second attempt: callers should treat this as "fire once".
    const debitRef = `${templateId}:${Date.now()}`;
    await this.gems.debit({
      userId,
      amount: tpl.gemPrice,
      source: 'CARD_PACK_PURCHASE',
      description: `Bought ${tpl.edition} (${tpl.rarity})`,
      refType: 'pack',
      refId: debitRef,
    });

    // Now mint. If this throws after the debit, the user is owed gems —
    // refund through the ledger so the audit trail stays balanced.
    try {
      return await this.minting.award({
        userId,
        templateId,
        source: 'DIRECT_PURCHASE',
      });
    } catch (err) {
      await this.gems.credit({
        userId,
        amount: tpl.gemPrice,
        source: 'ADJUSTMENT',
        description: `Refund — mint failed for ${tpl.edition}`,
        refType: 'pack-refund',
        refId: debitRef,
      });
      throw err;
    }
  }

  /** Featured templates the user can spend gems on right now. Drives the
   *  wallet store list. Returns only `purchasable && gemPrice` templates
   *  that are inside their drop window. */
  async featuredForSale() {
    const now = new Date();
    const rows = await this.prisma.cardTemplate.findMany({
      where: {
        purchasable: true,
        gemPrice: { not: null },
        OR: [
          { dropOpensAt: null },
          { dropOpensAt: { lte: now } },
        ],
        AND: [
          {
            OR: [
              { dropClosesAt: null },
              { dropClosesAt: { gt: now } },
            ],
          },
        ],
      },
      include: { player: { include: { team: true } } },
      orderBy: [{ rarity: 'desc' }, { gemPrice: 'asc' }],
      take: 24,
    });
    return rows.map((t) => ({
      id: t.id,
      edition: t.edition,
      rarity: t.rarity,
      totalSupply: t.totalSupply,
      mintedCount: t.mintedCount,
      artUrl: t.artUrl,
      frameStyle: t.frameStyle,
      gemPrice: t.gemPrice,
      maxPerUser: t.maxPerUser ?? null,
      dropOpensAt: t.dropOpensAt ?? null,
      dropClosesAt: t.dropClosesAt ?? null,
      playerName: t.player?.name ?? null,
      teamName: t.player?.team?.name ?? null,
      teamCrestUrl: t.player?.team?.crestUrl ?? null,
    }));
  }

  // ─── Transparent bundles ("packs" with KNOWN contents) ────────────────────
  // A bundle is a fixed list of cards sold for a fixed gem price — the buyer
  // sees exactly what they get before paying. No randomness → halal, and a
  // repeatable gem sink. Priced at a slight discount vs buying the members
  // singly (see BUNDLE_DISCOUNT).

  /** Active bundles inside their availability window, enriched for display:
   *  each member card flattened, plus the "save vs singly" delta and per-user
   *  ownership flags. Sold-out members are flagged but the bundle stays
   *  listed (the cards are minted on purchase). */
  async listBundles(userId: string) {
    const now = new Date();
    const bundles = await this.prisma.cardBundle.findMany({
      where: {
        active: true,
        OR: [{ dropOpensAt: null }, { dropOpensAt: { lte: now } }],
        AND: [{ OR: [{ dropClosesAt: null }, { dropClosesAt: { gt: now } }] }],
      },
      include: {
        entries: {
          include: { template: { include: { player: { include: { team: true } } } } },
        },
      },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
    });

    // Which of the member templates does this user already own? (Drives a
    // subtle "you already own this" hint — they still get a tradeable copy.)
    const templateIds = [
      ...new Set(bundles.flatMap((b) => b.entries.map((e) => e.templateId))),
    ];
    const ownedRows = templateIds.length
      ? await this.prisma.ownedCard.findMany({
          where: { ownerId: userId, templateId: { in: templateIds } },
          select: { templateId: true },
        })
      : [];
    const ownedSet = new Set(ownedRows.map((o) => o.templateId));

    return bundles.map((b) => {
      const cards = b.entries.map((e) => {
        const t = e.template;
        return {
          templateId: t.id,
          edition: t.edition,
          rarity: t.rarity,
          totalSupply: t.totalSupply,
          mintedCount: t.mintedCount,
          artUrl: t.artUrl,
          frameStyle: t.frameStyle,
          playerName: t.player?.name ?? null,
          teamName: t.player?.team?.name ?? null,
          teamCrestUrl: t.player?.team?.crestUrl ?? null,
          singlePrice: cardGemPrice(t.rarity),
          ownedByMe: ownedSet.has(t.id),
          soldOut: t.mintedCount >= t.totalSupply,
        };
      });
      const singleTotal = cards.reduce((s, c) => s + (c.singlePrice ?? 0), 0);
      return {
        id: b.id,
        name: b.name,
        description: b.description,
        gemPrice: b.gemPrice,
        artUrl: b.artUrl,
        dropClosesAt: b.dropClosesAt ?? null,
        cards,
        cardCount: cards.length,
        // Headline "save N gems" — only meaningful when the singles are
        // priced and cost more than the bundle.
        singleTotal,
        saving: singleTotal > b.gemPrice ? singleTotal - b.gemPrice : 0,
        soldOut: cards.some((c) => c.soldOut),
      };
    });
  }

  /** Buy a bundle: debit gems once, then mint every member card atomically
   *  (all-or-nothing). Mirrors purchaseCard's debit→act→refund pattern, but
   *  the whole mint runs in ONE transaction so a sold-out member can't leave
   *  the user half-charged. Returns the enriched minted cards for the reveal. */
  async purchaseBundle(userId: string, bundleId: string) {
    const bundle = await this.prisma.cardBundle.findUnique({
      where: { id: bundleId },
      include: { entries: { include: { template: true } } },
    });
    if (!bundle || !bundle.active) throw new NotFoundException('bundle_not_found');
    if (!bundle.entries.length) throw new BadRequestException('bundle_empty');

    const now = new Date();
    if (bundle.dropOpensAt && bundle.dropOpensAt.getTime() > now.getTime())
      throw new BadRequestException('drop_not_open_yet');
    if (bundle.dropClosesAt && bundle.dropClosesAt.getTime() <= now.getTime())
      throw new BadRequestException('drop_closed');

    // Pre-flight: every member must have supply + an open window. Catches the
    // common "sold out" case BEFORE any gems move, so the refund path below is
    // only ever hit on a genuine concurrent-buyer race.
    for (const e of bundle.entries) {
      const t = e.template;
      if (t.mintedCount >= t.totalSupply) throw new BadRequestException('sold_out');
      if (t.dropOpensAt && t.dropOpensAt.getTime() > now.getTime())
        throw new BadRequestException('drop_not_open_yet');
      if (t.dropClosesAt && t.dropClosesAt.getTime() <= now.getTime())
        throw new BadRequestException('drop_closed');
    }

    // Debit once through the ledger (audited, dedupe-protected).
    const debitRef = `${bundleId}:${Date.now()}`;
    await this.gems.debit({
      userId,
      amount: bundle.gemPrice,
      source: 'CARD_PACK_PURCHASE',
      description: `Bought bundle “${bundle.name}”`,
      refType: 'bundle',
      refId: debitRef,
    });

    try {
      // Atomic mint of every member. Incrementing then re-checking the cap
      // inside the txn makes a sold-out race roll the WHOLE bundle back.
      const mintedIds = await this.prisma.$transaction(
        async (tx) => {
          const ids: string[] = [];
          for (const e of bundle.entries) {
            const updated = await tx.cardTemplate.update({
              where: { id: e.templateId },
              data: { mintedCount: { increment: 1 } },
            });
            if (updated.mintedCount > updated.totalSupply)
              throw new BadRequestException('sold_out');
            const card = await tx.ownedCard.create({
              data: {
                templateId: e.templateId,
                serialNumber: updated.mintedCount,
                ownerId: userId,
                firstOwnerId: userId,
                acquiredVia: 'DIRECT_PURCHASE',
                mintReason: `Bundle: ${bundle.name}`,
              },
            });
            ids.push(card.id);
          }
          return ids;
        },
        { isolationLevel: Prisma.TransactionIsolationLevel.Serializable, timeout: 12_000 },
      );

      const cards = await Promise.all(mintedIds.map((id) => this.getOwnedCard(userId, id)));
      return { bundleId, name: bundle.name, gemPrice: bundle.gemPrice, cards };
    } catch (err) {
      // Mint failed wholesale (txn rolled back) — refund the gems so the
      // ledger stays balanced, then surface the error.
      await this.gems.credit({
        userId,
        amount: bundle.gemPrice,
        source: 'ADJUSTMENT',
        description: `Refund — bundle “${bundle.name}” mint failed`,
        refType: 'bundle-refund',
        refId: debitRef,
      });
      throw err;
    }
  }

  // ─── Set completion ────────────────────────────────────────────────────────
  /// Idempotently award completion rewards when the user holds every entry.
  ///
  /// First completion awards:
  ///   1. `set.rewardCoins` (when > 0)
  ///   2. A copy of `set.masterTemplate` if set — the "Set Master" card,
  ///      a one-of-N unique flex you can only get by completing the set.
  ///      Stamped with a `SET:<setId>` trophy code and `mintReason` so
  ///      the card's identity tells its origin story.
  ///
  /// All idempotent: re-checking after completion returns the same flags
  /// without minting twice. We detect "first completion" via the upsert's
  /// `completedAt` timestamp.
  async checkSetCompletion(userId: string, setId: string) {
    const set = await this.prisma.cardSet.findUnique({
      where: { id: setId },
      include: { entries: true, masterTemplate: true },
    });
    if (!set) throw new NotFoundException('set_not_found');

    const owned = await this.prisma.ownedCard.findMany({
      where: { ownerId: userId, templateId: { in: set.entries.map((e) => e.templateId) } },
      select: { templateId: true },
    });
    const ownedIds = new Set(owned.map((o) => o.templateId));
    if (!set.entries.every((e) => ownedIds.has(e.templateId))) return { completed: false };

    const result = await this.prisma.setCompletion.upsert({
      where: { setId_userId: { setId, userId } },
      create: { setId, userId },
      update: {},
    });
    const isFirstCompletion = Date.now() - result.completedAt.getTime() < 1000;

    let masterCardId: string | null = null;
    if (isFirstCompletion) {
      // Coin reward (existing behaviour).
      if (set.rewardCoins > 0) {
        await this.prisma.user.update({
          where: { id: userId },
          data: { coins: { increment: set.rewardCoins } },
        });
      }
      // Set Master mint (new). Idempotent under retries: check if the
      // user already owns a copy of the master template for this set
      // — if so, treat it as already-minted rather than double-issuing.
      if (set.masterTemplate) {
        const existing = await this.prisma.ownedCard.findFirst({
          where: { ownerId: userId, templateId: set.masterTemplate.id },
          select: { id: true },
        });
        if (existing) {
          masterCardId = existing.id;
        } else {
          // Mint atomically: bump mintedCount + create OwnedCard with the
          // next serial. SET_COMPLETION acquisition source flags it as
          // earned (not bought / not signup gift) in the audit trail.
          try {
            const minted = await this.prisma.$transaction(async (tx) => {
              const updatedTpl = await tx.cardTemplate.update({
                where: { id: set.masterTemplate!.id },
                data: { mintedCount: { increment: 1 } },
                select: { mintedCount: true },
              });
              return tx.ownedCard.create({
                data: {
                  templateId: set.masterTemplate!.id,
                  serialNumber: updatedTpl.mintedCount,
                  ownerId: userId,
                  firstOwnerId: userId,
                  acquiredVia: 'SET_COMPLETION',
                  mintReason: `Completed the "${set.name}" set`,
                  trophies: [`SET:${set.id}`],
                },
                select: { id: true },
              });
            });
            masterCardId = minted.id;
          } catch (e) {
            // Mint failed — log but don't fail the set completion. The
            // user still has their coins; we can retry the master mint
            // on the next check.
            // eslint-disable-next-line no-console
            console.warn(`[set-completion] master mint failed for set=${setId}: ${(e as Error).message}`);
          }
        }
      }
    }

    return {
      completed: true,
      rewardCoins: set.rewardCoins,
      rewardFrame: set.rewardFrame,
      masterCardId,
      masterTemplate: set.masterTemplate
        ? {
            id: set.masterTemplate.id,
            rarity: set.masterTemplate.rarity,
            edition: set.masterTemplate.edition,
            artUrl: set.masterTemplate.artUrl,
          }
        : null,
    };
  }
}
