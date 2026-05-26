import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { H2HController } from './h2h.controller';
import { H2HService } from './h2h.service';

@Module({
  imports: [AuthModule, NotificationsModule],
  providers: [H2HService],
  controllers: [H2HController],
  exports: [H2HService],
})
export class H2HModule {}
