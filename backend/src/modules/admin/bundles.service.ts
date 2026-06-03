import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma.service';
import { cardGemPrice } from '../cards/cards.pricing';

export interface BundleInput {
  name: string;
  description?: string | null;
  gemPrice: number;
  artUrl?: string | null;
  active: boolean;
  sortOrder: number;
  templateIds: string[];
}

/// Admin CRUD for transparent card bundles ("packs" with known contents).
/// The admin picks any templates, a price, and a name — no randomness.
@Injectable()
export class AdminBundlesService {
  constructor(private readonly prisma: PrismaService) {}

  async list() {
    const bundles = await this.prisma.cardBundle.findMany({
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
      include: {
        entries: {
          include: { template: { include: { player: { select: { name: true } } } } },
        },
      },
    });
    return bundles.map((b) => {
      const cards = b.entries.map((e) => ({
        templateId: e.templateId,
        rarity: e.template.rarity,
        edition: e.template.edition,
        artUrl: e.template.artUrl,
        playerName: e.template.player?.name ?? null,
        singlePrice: cardGemPrice(e.template.rarity),
      }));
      const singleTotal = cards.reduce((s, c) => s + (c.singlePrice ?? 0), 0);
      return {
        id: b.id,
        name: b.name,
        description: b.description,
        gemPrice: b.gemPrice,
        artUrl: b.artUrl,
        active: b.active,
        sortOrder: b.sortOrder,
        cards,
        cardCount: cards.length,
        singleTotal,
        saving: singleTotal > b.gemPrice ? singleTotal - b.gemPrice : 0,
      };
    });
  }

  /// Validate that every id is a real, distinct template. Returns the deduped
  /// list so callers store each card at most once per bundle.
  private async resolveTemplateIds(ids: string[]): Promise<string[]> {
    const unique = [...new Set(ids.map((s) => s.trim()).filter(Boolean))];
    if (!unique.length) throw new BadRequestException('bundle_needs_at_least_one_card');
    const found = await this.prisma.cardTemplate.count({ where: { id: { in: unique } } });
    if (found !== unique.length) throw new BadRequestException('unknown_template_in_bundle');
    return unique;
  }

  async create(input: BundleInput): Promise<{ id: string }> {
    if (!input.name.trim()) throw new BadRequestException('name_required');
    if (input.gemPrice <= 0) throw new BadRequestException('gem_price_must_be_positive');
    const ids = await this.resolveTemplateIds(input.templateIds);
    const bundle = await this.prisma.cardBundle.create({
      data: {
        name: input.name.trim(),
        description: input.description?.trim() || null,
        gemPrice: input.gemPrice,
        artUrl: input.artUrl?.trim() || null,
        active: input.active,
        sortOrder: input.sortOrder,
        entries: { create: ids.map((templateId) => ({ templateId })) },
      },
    });
    return { id: bundle.id };
  }

  async update(id: string, input: BundleInput): Promise<{ id: string }> {
    const existing = await this.prisma.cardBundle.findUnique({ where: { id }, select: { id: true } });
    if (!existing) throw new NotFoundException('bundle_not_found');
    if (!input.name.trim()) throw new BadRequestException('name_required');
    if (input.gemPrice <= 0) throw new BadRequestException('gem_price_must_be_positive');
    const ids = await this.resolveTemplateIds(input.templateIds);
    // Replace the membership wholesale inside one transaction so the bundle
    // never briefly has zero or duplicate entries.
    await this.prisma.$transaction([
      this.prisma.cardBundleEntry.deleteMany({ where: { bundleId: id } }),
      this.prisma.cardBundle.update({
        where: { id },
        data: {
          name: input.name.trim(),
          description: input.description?.trim() || null,
          gemPrice: input.gemPrice,
          artUrl: input.artUrl?.trim() || null,
          active: input.active,
          sortOrder: input.sortOrder,
          entries: { create: ids.map((templateId) => ({ templateId })) },
        },
      }),
    ]);
    return { id };
  }

  async remove(id: string): Promise<{ id: string }> {
    const existing = await this.prisma.cardBundle.findUnique({ where: { id }, select: { id: true } });
    if (!existing) throw new NotFoundException('bundle_not_found');
    await this.prisma.cardBundle.delete({ where: { id } }); // entries cascade
    return { id };
  }
}
