import { Module } from '@nestjs/common';
import { ApiFootballModule } from '../api-football/api-football.module';
import { AuthModule } from '../auth/auth.module';
import { AiController } from './ai.controller';
import { AiService } from './ai.service';
import { MatchPreviewService } from './match-preview.service';

@Module({
  imports: [AuthModule, ApiFootballModule],
  controllers: [AiController],
  providers: [AiService, MatchPreviewService],
  exports: [AiService],
})
export class AiModule {}
