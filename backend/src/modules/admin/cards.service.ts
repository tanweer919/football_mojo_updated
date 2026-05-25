import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { CardRarity } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';

interface ListInput {
  q?: string;
  rarity?: CardRarity;
  playerId?: string;
  page: number;
  pageSize: number;
}

interface UpdateInput {
  edition: string;
  rarity: CardRarity;
  totalSupply: number;
  artUrl: string;
  frameStyle: string;
  giftableOnly: boolean;
  purchasable: boolean;
  gemPrice: number | null;
}

@Injectable()
export class AdminCardsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(input: ListInput) {
    const where = {
      AND: [
        input.rarity ? { rarity: input.rarity } : {},
        input.playerId ? { playerId: input.playerId } : {},
        input.q ? { player: { name: { contains: input.q, mode: 'insensitive' as const } } } : {},
      ],
    };
    const [rows, total] = await Promise.all([
      this.prisma.cardTemplate.findMany({
        where,
        include: {
          player: { include: { team: { select: { shortName: true, crestUrl: true } } } },
        },
        orderBy: [{ rarity: 'desc' }, { edition: 'asc' }],
        take: input.pageSize,
        skip: (input.page - 1) * input.pageSize,
      }),
      this.prisma.cardTemplate.count({ where }),
    ]);
    return { rows, total };
  }

  async getById(id: string) {
    const tpl = await this.prisma.cardTemplate.findUnique({
      where: { id },
      include: {
        player: { include: { team: { select: { name: true, shortName: true, crestUrl: true } } } },
      },
    });
    if (!tpl) throw new NotFoundException('template_not_found');
    return tpl;
  }

  async update(id: string, input: UpdateInput) {
    const tpl = await this.prisma.cardTemplate.findUnique({
      where: { id },
      select: { mintedCount: true },
    });
    if (!tpl) throw new NotFoundException('template_not_found');

    // Block lowering totalSupply below mintedCount — that would imply
    // un-minting circulating cards and break OwnedCard serial uniqueness.
    if (input.totalSupply < tpl.mintedCount) {
      throw new BadRequestException(
        `total_supply_below_minted_count: ${input.totalSupply} < ${tpl.mintedCount}`,
      );
    }
    if (input.purchasable && (input.gemPrice == null || input.gemPrice <= 0)) {
      throw new BadRequestException('purchasable_requires_gem_price');
    }

    await this.prisma.cardTemplate.update({
      where: { id },
      data: {
        edition: input.edition.trim(),
        rarity: input.rarity,
        totalSupply: input.totalSupply,
        artUrl: input.artUrl.trim(),
        frameStyle: input.frameStyle.trim() || 'base',
        giftableOnly: input.giftableOnly,
        purchasable: input.purchasable,
        gemPrice: input.gemPrice,
      },
    });
  }
}
