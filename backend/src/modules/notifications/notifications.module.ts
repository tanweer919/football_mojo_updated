import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { NotificationsDispatcher } from './notifications.dispatcher';
import { PushService } from './push.service';
import { WcDigestWorker } from './wc-digest.worker';

@Module({
  imports: [AuthModule],
  providers: [NotificationsDispatcher, PushService, WcDigestWorker],
  exports: [NotificationsDispatcher, PushService],
})
export class NotificationsModule {}
