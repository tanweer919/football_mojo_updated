import { Body, Controller, Get, Param, Patch, Query, UseGuards } from '@nestjs/common';
import { IsBoolean, IsIn, IsInt, IsOptional, IsString, Min } from 'class-validator';
import { CardRarity } from '@prisma/client';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { AdminRoleGuard } from './admin-role.guard';
import { AdminCardsService } from './cards.service';

const RARITIES: CardRarity[] = ['COMMON', 'UNCOMMON', 'RARE', 'EPIC', 'LEGENDARY', 'ICONIC'];

class UpdateCardBody {
  @IsString() edition!: string;
  @IsIn(RARITIES) rarity!: CardRarity;
  @IsInt() @Min(0) totalSupply!: number;
  @IsString() artUrl!: string;
  @IsString() frameStyle!: string;
  @IsBoolean() giftableOnly!: boolean;
  @IsBoolean() purchasable!: boolean;
  @IsOptional() @IsInt() @Min(0) gemPrice?: number | null;
}

@Controller({ path: 'admin/cards', version: '1' })
@UseGuards(FirebaseAuthGuard, AdminRoleGuard)
export class AdminCardsController {
  constructor(private readonly cards: AdminCardsService) {}

  @Get()
  list(
    @Query('q') q?: string,
    @Query('rarity') rarity?: string,
    @Query('playerId') playerId?: string,
    @Query('page') page?: string,
    @Query('pageSize') pageSize?: string,
  ) {
    return this.cards.list({
      q: q?.trim() || undefined,
      rarity: RARITIES.includes(rarity as CardRarity) ? (rarity as CardRarity) : undefined,
      playerId: playerId?.trim() || undefined,
      page: Math.max(1, Number.parseInt(page ?? '1', 10) || 1),
      pageSize: Math.min(100, Math.max(1, Number.parseInt(pageSize ?? '40', 10) || 40)),
    });
  }

  @Get(':id')
  getOne(@Param('id') id: string) {
    return this.cards.getById(id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() body: UpdateCardBody) {
    return this.cards.update(id, {
      edition: body.edition,
      rarity: body.rarity,
      totalSupply: body.totalSupply,
      artUrl: body.artUrl,
      frameStyle: body.frameStyle,
      giftableOnly: body.giftableOnly,
      purchasable: body.purchasable,
      gemPrice: body.gemPrice ?? null,
    });
  }
}
