import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module';
import { NewsController } from './news.controller';
import { NewsService } from './news.service';
import { RssAggregatorService } from './rss-aggregator.service';

@Module({
  imports: [NotificationsModule],
  providers: [NewsService, RssAggregatorService],
  controllers: [NewsController],
  exports: [NewsService],
})
export class NewsModule {}
