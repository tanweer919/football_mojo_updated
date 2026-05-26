import { Module, forwardRef } from '@nestjs/common';
import { ApiFootballModule } from '../api-football/api-football.module';
import { AuthModule } from '../auth/auth.module';
import { GemsModule } from '../gems/gems.module';
import { GlobalCupModule } from '../global-cup/global-cup.module';
import { H2HModule } from '../h2h/h2h.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { FantasyController } from './fantasy.controller';
import { FantasyService } from './fantasy.service';
import { FantasyPricingService } from './pricing.service';
import { ScoringRulesController } from './scoring-rules.controller';
import { FantasyScoringService } from './scoring.service';
import { FantasyScoringWorker } from './scoring.worker';

@Module({
  imports: [
    AuthModule,
    ApiFootballModule,
    GemsModule,
    NotificationsModule,
    forwardRef(() => H2HModule),
    forwardRef(() => GlobalCupModule),
  ],
  providers: [FantasyService, FantasyScoringService, FantasyPricingService, FantasyScoringWorker],
  controllers: [FantasyController, ScoringRulesController],
  exports: [FantasyService, FantasyScoringService, FantasyScoringWorker],
})
export class FantasyModule {}
