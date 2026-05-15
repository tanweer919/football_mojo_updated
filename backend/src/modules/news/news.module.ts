import { Module } from '@nestjs/common';
import { NewsController } from './news.controller';
import { NewsService } from './news.service';
import { RssAggregatorService } from './rss-aggregator.service';

@Module({
  providers: [NewsService, RssAggregatorService],
  controllers: [NewsController],
  exports: [NewsService],
})
export class NewsModule {}
