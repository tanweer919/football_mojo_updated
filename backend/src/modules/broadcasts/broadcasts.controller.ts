import { CacheInterceptor, CacheTTL } from '@nestjs/cache-manager';
import { Controller, Get, Param, UseInterceptors } from '@nestjs/common';
import { BroadcastsService } from './broadcasts.service';

/**
 * Public "where to watch" endpoint, mounted alongside the other insights
 * routes (`GET /v1/insights/broadcasts/:fixtureId`). No auth — consumed by the
 * mobile app and the public web site. Cached 10min via the HTTP cache.
 */
@Controller({ path: 'insights', version: '1' })
@UseInterceptors(CacheInterceptor)
export class BroadcastsController {
  constructor(private readonly broadcasts: BroadcastsService) {}

  @Get('broadcasts/:fixtureId')
  @CacheTTL(600_000)
  byFixture(@Param('fixtureId') fixtureId: string) {
    return this.broadcasts.groupedByMatch(fixtureId);
  }
}
