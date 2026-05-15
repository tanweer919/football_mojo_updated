import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { AcquisitionSource, Prisma } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';
import { MintingService } from './minting.service';

@Injectable()
export class CardsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly minting: MintingService,
  ) {}

  // ─── Album view ────────────────────────────────────────────────────────────
  // Returns the user's full sticker-album: every template grouped by set,
  // with owned-count + duplicate-count so the UI can show "owned / needed / dupes".
  async getAlbum(userId: string) {
    const [sets, owned] = await Promise.all([
      this.prisma.cardSet.findMany({
        include: { entries: { include: { template: { include: { player: { include: { team: true } } } } } } },
      }),
      this.prisma.ownedCard.findMany({
        where: { ownerId: userId },
        select: { id: true, templateId: true, mintedAt: true },
        orderBy: { mintedAt: 'asc' },
      }),
    ]);

    const ownedCount = new Map<string, number>();
    const firstOwnedByTemplate = new Map<string, string>();
    for (const o of owned) {
      ownedCount.set(o.templateId, (ownedCount.get(o.templateId) ?? 0) + 1);
      if (!firstOwnedByTemplate.has(o.templateId)) firstOwnedByTemplate.set(o.templateId, o.id);
    }

    return sets.map((s) => ({
      id: s.id,
      name: s.name,
      description: s.description,
      total: s.entries.length,
      completedCount: s.entries.filter((e) => (ownedCount.get(e.templateId) ?? 0) > 0).length,
      entries: s.entries.map((e) => ({
        templateId: e.templateId,
        template: e.template,
        owned: ownedCount.get(e.templateId) ?? 0,
        firstOwnedCardId: firstOwnedByTemplate.get(e.templateId) ?? null,
      })),
    }));
  }

  async listOwned(userId: string) {
    return this.prisma.ownedCard.findMany({
      where: { ownerId: userId },
      include: { template: { include: { player: { include: { team: true } } } } },
      orderBy: { mintedAt: 'desc' },
    });
  }

  async getOwnedCard(userId: string, ownedCardId: string) {
    const card = await this.prisma.ownedCard.findFirst({
      where: { id: ownedCardId, ownerId: userId },
      include: { template: { include: { player: { include: { team: true } } } } },
    });
    if (!card) throw new NotFoundException('card_not_found');
    return card;
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

    return this.minting.award({ userId, templateId: tpl.id, source: 'DAILY_LOGIN' });
  }

  // Rewarded-ad mint: user watches a 30s ad, server validates the ad SSV callback
  // (signed token verified upstream of this method) and mints a specific common card.
  async claimRewardedAd(userId: string) {
    // Pick the next common card the user is MISSING from their album. Fully deterministic.
    const missing = await this.prisma.$queryRaw<Array<{ id: string }>>(Prisma.sql`
      SELECT t.id FROM "CardTemplate" t
      WHERE t.rarity = 'COMMON' AND t."giftableOnly" = true
        AND NOT EXISTS (
          SELECT 1 FROM "OwnedCard" o
          WHERE o."templateId" = t.id AND o."ownerId" = ${userId}
        )
      ORDER BY t.id ASC
      LIMIT 1;
    `);
    if (!missing.length) throw new BadRequestException('album_complete_for_commons');
    return this.minting.award({ userId, templateId: missing[0]!.id, source: 'REWARDED_AD' });
  }

  // ─── Direct purchase (halal IAP) ──────────────────────────────────────────
  // User explicitly buys a NAMED card for a KNOWN gem price. No uncertainty.
  async purchaseCard(userId: string, templateId: string) {
    return this.prisma.$transaction(async (tx) => {
      const tpl = await tx.cardTemplate.findUnique({ where: { id: templateId } });
      if (!tpl) throw new NotFoundException('template_not_found');
      if (!tpl.purchasable || !tpl.gemPrice)
        throw new BadRequestException('not_purchasable');
      if (tpl.mintedCount >= tpl.totalSupply)
        throw new BadRequestException('sold_out');

      const user = await tx.user.findUnique({ where: { id: userId } });
      if (!user) throw new NotFoundException('user_not_found');
      if (user.gems < tpl.gemPrice) throw new BadRequestException('insufficient_gems');

      await tx.user.update({
        where: { id: userId },
        data: { gems: { decrement: tpl.gemPrice } },
      });
      // Mint using the same SERIALIZABLE path.
      const updated = await tx.cardTemplate.update({
        where: { id: templateId },
        data: { mintedCount: { increment: 1 } },
      });
      return tx.ownedCard.create({
        data: {
          templateId,
          serialNumber: updated.mintedCount,
          ownerId: userId,
          firstOwnerId: userId,
          acquiredVia: 'DIRECT_PURCHASE',
        },
      });
    });
  }

  // ─── Set completion ────────────────────────────────────────────────────────
  // Idempotently award completion rewards when the user holds every entry.
  async checkSetCompletion(userId: string, setId: string) {
    const set = await this.prisma.cardSet.findUnique({
      where: { id: setId },
      include: { entries: true },
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
    // Award coins only on first completion (createdAt within last second).
    if (Date.now() - result.completedAt.getTime() < 1000 && set.rewardCoins > 0) {
      await this.prisma.user.update({
        where: { id: userId },
        data: { coins: { increment: set.rewardCoins } },
      });
    }
    return { completed: true, rewardCoins: set.rewardCoins, rewardFrame: set.rewardFrame };
  }
}
