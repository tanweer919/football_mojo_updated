import { CacheInterceptor, CacheTTL } from '@nestjs/cache-manager';
import { Controller, Get, Param, Query, UseInterceptors } from '@nestjs/common';
import { NewsService } from './news.service';

@Controller({ path: 'news', version: '1' })
@UseInterceptors(CacheInterceptor)
export class NewsController {
  constructor(private readonly news: NewsService) {}

  @Get()
  @CacheTTL(60_000)
  list(
    @Query('limit') limit?: string,
    @Query('cursor') cursor?: string,
    @Query('teamId') teamId?: string,
    // Comma-separated list of team IDs for the "Following" tab.
    // Articles matching ANY of them are returned.
    @Query('teamIds') teamIds?: string,
    @Query('source') source?: string,
  ) {
    return this.news.list({
      limit: limit ? +limit : undefined,
      cursor,
      teamId,
      teamIds: teamIds ? teamIds.split(',').map((t) => t.trim()).filter(Boolean) : undefined,
      source,
    });
  }

  @Get(':id')
  @CacheTTL(300_000)
  byId(@Param('id') id: string) {
    return this.news.getById(id);
  }
}
