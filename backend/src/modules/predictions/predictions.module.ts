import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { CardsModule } from '../cards/cards.module';
import { GemsModule } from '../gems/gems.module';
import { BracketScoringWorker } from './bracket-scoring.worker';
import { PredictionsController } from './predictions.controller';
import { PredictionsService } from './predictions.service';

@Module({
  imports: [AuthModule, CardsModule, GemsModule],
  providers: [PredictionsService, BracketScoringWorker],
  controllers: [PredictionsController],
  exports: [PredictionsService],
})
export class PredictionsModule {}
