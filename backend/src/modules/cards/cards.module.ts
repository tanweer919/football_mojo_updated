import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { CardsController } from './cards.controller';
import { CardsService } from './cards.service';
import { MintingService } from './minting.service';
import { TradeService } from './trade.service';

@Module({
  imports: [AuthModule],
  providers: [MintingService, CardsService, TradeService],
  controllers: [CardsController],
  exports: [MintingService, CardsService],
})
export class CardsModule {}
