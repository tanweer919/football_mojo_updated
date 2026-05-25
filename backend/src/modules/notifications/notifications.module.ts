import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { NotificationsDispatcher } from './notifications.dispatcher';

@Module({
  imports: [AuthModule],
  providers: [NotificationsDispatcher],
  exports: [NotificationsDispatcher],
})
export class NotificationsModule {}
