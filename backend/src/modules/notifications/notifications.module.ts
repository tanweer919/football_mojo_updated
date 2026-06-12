import { Module } from '@nestjs/common';
import { ApiFootballModule } from '../api-football/api-football.module';
import { AuthModule } from '../auth/auth.module';
import { LineupWorker } from './lineup.worker';
import { NotificationsDispatcher } from './notifications.dispatcher';
import { PushService } from './push.service';
import { WcDigestWorker } from './wc-digest.worker';

@Module({
  imports: [AuthModule, ApiFootballModule],
  providers: [NotificationsDispatcher, PushService, WcDigestWorker, LineupWorker],
  exports: [NotificationsDispatcher, PushService],
})
export class NotificationsModule {}
