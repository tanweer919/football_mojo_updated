import { Global, Module } from '@nestjs/common';
import { ApiFootballCacheService } from './api-football-cache.service';
import { ApiFootballClient } from './api-football.client';

@Global()
@Module({
  providers: [ApiFootballClient, ApiFootballCacheService],
  exports: [ApiFootballClient, ApiFootballCacheService],
})
export class ApiFootballModule {}
