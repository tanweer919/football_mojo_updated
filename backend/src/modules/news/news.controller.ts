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
    @Query('source') source?: string,
  ) {
    return this.news.list({ limit: limit ? +limit : undefined, cursor, teamId, source });
  }

  @Get(':id')
  @CacheTTL(300_000)
  byId(@Param('id') id: string) {
    return this.news.getById(id);
  }
}
