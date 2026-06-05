import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { AiController } from './ai.controller';
import { AiService } from './ai.service';
import { MatchPreviewService } from './match-preview.service';

@Module({
  imports: [AuthModule],
  controllers: [AiController],
  providers: [AiService, MatchPreviewService],
  exports: [AiService],
})
export class AiModule {}
