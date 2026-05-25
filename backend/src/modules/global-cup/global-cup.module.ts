import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { CardsModule } from '../cards/cards.module';
import { GlobalCupController } from './global-cup.controller';
import { GlobalCupService } from './global-cup.service';

@Module({
  imports: [AuthModule, CardsModule],
  providers: [GlobalCupService],
  controllers: [GlobalCupController],
  exports: [GlobalCupService],
})
export class GlobalCupModule {}
