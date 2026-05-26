import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, TradeStatus } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';

// Card-for-card barter only. No coins, no gems, no real money in trades.
// This keeps trading clearly halal (no riba, no gharar) and store-compliant.
@Injectable()
export class TradeService {
  constructor(private readonly prisma: PrismaService) {}

  async propose(params: {
    initiatorId: string;
    recipientId: string;
    offeredOwnedCardIds: string[];
    requestedOwnedCardIds: string[];
    message?: string;
  }) {
    if (params.initiatorId === params.recipientId)
      throw new BadRequestException('cannot_trade_with_self');
    if (!params.offeredOwnedCardIds.length || !params.requestedOwnedCardIds.length)
      throw new BadRequestException('empty_offer');

    const [mine, theirs] = await Promise.all([
      this.prisma.ownedCard.findMany({
        where: { id: { in: params.offeredOwnedCardIds }, ownerId: params.initiatorId },
      }),
      this.prisma.ownedCard.findMany({
        where: { id: { in: params.requestedOwnedCardIds }, ownerId: params.recipientId },
      }),
    ]);
    if (mine.length !== params.offeredOwnedCardIds.length)
      throw new BadRequestException('offered_cards_not_owned');
    if (theirs.length !== params.requestedOwnedCardIds.length)
      throw new BadRequestException('requested_cards_not_owned_by_recipient');

    return this.prisma.trade.create({
      data: {
        initiatorId: params.initiatorId,
        recipientId: params.recipientId,
        offered: params.offeredOwnedCardIds.map((id) => ({ ownedCardId: id })),
        requested: params.requestedOwnedCardIds.map((id) => ({ ownedCardId: id })),
        message: params.message ?? null,
        status: 'PENDING',
      },
    });
  }

  async respond(tradeId: string, recipientId: string, decision: 'ACCEPTED' | 'DECLINED') {
    return this.prisma.$transaction(
      async (tx) => {
        const trade = await tx.trade.findUnique({ where: { id: tradeId } });
        if (!trade) throw new NotFoundException('trade_not_found');
        if (trade.recipientId !== recipientId) throw new BadRequestException('not_recipient');
        if (trade.status !== 'PENDING') throw new BadRequestException('not_pending');

        if (decision === 'DECLINED') {
          return tx.trade.update({
            where: { id: tradeId },
            data: { status: 'DECLINED', resolvedAt: new Date() },
          });
        }

        const offered = (trade.offered as Array<{ ownedCardId: string }>).map((x) => x.ownedCardId);
        const requested = (trade.requested as Array<{ ownedCardId: string }>).map((x) => x.ownedCardId);

        // Re-validate ownership inside the transaction — guards against double-spend.
        const [stillMine, stillTheirs] = await Promise.all([
          tx.ownedCard.findMany({ where: { id: { in: offered }, ownerId: trade.initiatorId } }),
          tx.ownedCard.findMany({ where: { id: { in: requested }, ownerId: trade.recipientId } }),
        ]);
        if (stillMine.length !== offered.length || stillTheirs.length !== requested.length) {
          throw new BadRequestException('ownership_changed_since_proposal');
        }

        await tx.ownedCard.updateMany({
          where: { id: { in: offered } },
          data: { ownerId: trade.recipientId },
        });
        await tx.ownedCard.updateMany({
          where: { id: { in: requested } },
          data: { ownerId: trade.initiatorId },
        });

        return tx.trade.update({
          where: { id: tradeId },
          data: { status: 'ACCEPTED', resolvedAt: new Date() },
        });
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
    );
  }

  async cancel(tradeId: string, initiatorId: string) {
    const trade = await this.prisma.trade.findUnique({ where: { id: tradeId } });
    if (!trade) throw new NotFoundException('trade_not_found');
    if (trade.initiatorId !== initiatorId) throw new BadRequestException('not_initiator');
    if (trade.status !== 'PENDING') throw new BadRequestException('not_pending');
    return this.prisma.trade.update({
      where: { id: tradeId },
      data: { status: 'CANCELLED', resolvedAt: new Date() },
    });
  }

  async listIncoming(userId: string, status: TradeStatus = 'PENDING') {
    return this.prisma.trade.findMany({
      where: { recipientId: userId, status },
      orderBy: { createdAt: 'desc' },
    });
  }
}
