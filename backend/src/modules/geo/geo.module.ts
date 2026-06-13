import { Module } from '@nestjs/common';
import { GeoController } from './geo.controller';
import { GeoService } from './geo.service';

// Redis is provided globally (RedisModule is @Global), so no import needed.
@Module({
  controllers: [GeoController],
  providers: [GeoService],
})
export class GeoModule {}
