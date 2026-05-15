import { Module } from '@nestjs/common';
import { ApiFootballModule } from '../api-football/api-football.module';
import { InsightsController } from './insights.controller';

@Module({
  imports: [ApiFootballModule],
  controllers: [InsightsController],
})
export class InsightsModule {}
