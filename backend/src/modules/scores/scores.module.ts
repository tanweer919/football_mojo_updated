import { Module } from '@nestjs/common';
import { ApiFootballModule } from '../api-football/api-football.module';
import { HighlightsWorker } from './highlights.worker';
import { ScoresController } from './scores.controller';
import { ScoresGateway } from './scores.gateway';
import { ScoresPoller } from './scores.poller';
import { ScoresService } from './scores.service';

@Module({
  imports: [ApiFootballModule],
  providers: [ScoresService, ScoresPoller, ScoresGateway, HighlightsWorker],
  controllers: [ScoresController],
  exports: [ScoresService],
})
export class ScoresModule {}
