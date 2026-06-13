import { Module } from '@nestjs/common';
import { BroadcastsController } from './broadcasts.controller';
import { BroadcastsService } from './broadcasts.service';
import { IngestController } from './ingest.controller';

/**
 * "Where to watch" broadcast links. Public read (insights/broadcasts) + the
 * scraper ingest endpoint live here; admin CRUD lives in AdminModule but uses
 * this module's service (hence the export).
 */
@Module({
  providers: [BroadcastsService],
  controllers: [BroadcastsController, IngestController],
  exports: [BroadcastsService],
})
export class BroadcastsModule {}
