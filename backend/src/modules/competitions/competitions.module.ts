import { Module } from '@nestjs/common';
import { UsersModule } from '../users/users.module';
import { CompetitionsController } from './competitions.controller';
import { CompetitionsService } from './competitions.service';

@Module({
  // UsersModule exports UsersService which the team-search endpoint reuses.
  imports: [UsersModule],
  providers: [CompetitionsService],
  controllers: [CompetitionsController],
  exports: [CompetitionsService],
})
export class CompetitionsModule {}
