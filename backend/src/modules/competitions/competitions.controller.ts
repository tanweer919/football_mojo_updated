import { CacheInterceptor, CacheTTL } from '@nestjs/cache-manager';
import { Controller, Get, Param, Query, UseInterceptors } from '@nestjs/common';
import { CompetitionsService } from './competitions.service';

@Controller({ path: 'competitions', version: '1' })
@UseInterceptors(CacheInterceptor)
export class CompetitionsController {
  constructor(private readonly competitions: CompetitionsService) {}

  /**
   * App startup call. Cached for 5 min on the server so a million clients
   * fetching at once == a few hundred DB queries per minute.
   */
  @Get()
  @CacheTTL(300_000)
  list(@Query('active') active?: string) {
    return this.competitions.list({ onlyActive: active === 'true' });
  }

  @Get('primary')
  @CacheTTL(300_000)
  primary() {
    return this.competitions.primary();
  }

  @Get(':id')
  @CacheTTL(300_000)
  get(@Param('id') id: string) {
    return this.competitions.get(id);
  }

  @Get(':id/overview')
  @CacheTTL(300_000)
  overview(@Param('id') id: string) {
    return this.competitions.overview(id);
  }

  @Get(':id/groups')
  @CacheTTL(300_000)
  groups(@Param('id') id: string) {
    return this.competitions.groups(id);
  }
}
