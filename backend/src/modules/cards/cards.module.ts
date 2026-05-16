import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { CardsController } from './cards.controller';
import { CardsService } from './cards.service';
import { MarketController } from './market.controller';
import { MarketService } from './market.service';
import { MintingService } from './minting.service';
import { TradeService } from './trade.service';

@Module({
  imports: [AuthModule],
  providers: [MintingService, CardsService, TradeService, MarketService],
  controllers: [CardsController, MarketController],
  exports: [MintingService, CardsService, MarketService],
})
export class CardsModule {}
