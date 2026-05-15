import { BadRequestException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { AcquisitionSource, OwnedCard, Prisma } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';

// Server-side scarcity enforcement.
// Every mint is a single transaction that increments mintedCount under SERIALIZABLE
// isolation and refuses to exceed totalSupply. No blockchain — Postgres IS the chain.
@Injectable()
export class MintingService {
  private readonly log = new Logger(MintingService.name);

  constructor(private readonly prisma: PrismaService) {}

  async mint(params: {
    templateId: string;
    ownerId: string;
    source: AcquisitionSource;
  }): Promise<OwnedCard> {
    return this.prisma.$transaction(
      async (tx) => {
        const tpl = await tx.cardTemplate.findUnique({ where: { id: params.templateId } });
        if (!tpl) throw new NotFoundException('template_not_found');
        if (tpl.mintedCount >= tpl.totalSupply)
          throw new BadRequestException('template_sold_out');

        const updated = await tx.cardTemplate.update({
          where: { id: params.templateId },
          data: { mintedCount: { increment: 1 } },
        });

        return tx.ownedCard.create({
          data: {
            templateId: tpl.id,
            serialNumber: updated.mintedCount,            // post-increment value
            ownerId: params.ownerId,
            firstOwnerId: params.ownerId,
            acquiredVia: params.source,
          },
        });
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.Serializable, timeout: 8_000 },
    );
  }

  // Deterministic award: caller passes a templateId — no randomness involved.
  // Used by predictions, achievements, set completion, daily login, IAP, rewarded ads.
  async award(opts: { userId: string; templateId: string; source: AcquisitionSource }) {
    const card = await this.mint({
      templateId: opts.templateId,
      ownerId: opts.userId,
      source: opts.source,
    });
    this.log.log(`awarded card ${card.id} (#${card.serialNumber}) to ${opts.userId} via ${opts.source}`);
    return card;
  }
}
