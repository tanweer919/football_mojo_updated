import { Controller, Get, Inject } from '@nestjs/common';
import Redis from 'ioredis';
import { PrismaService } from './prisma.service';
import { REDIS_PUB } from './redis.module';

@Controller({ path: 'health', version: undefined })
export class HealthController {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(REDIS_PUB) private readonly redis: Redis,
  ) {}

  @Get()
  async check() {
    const [db, cache] = await Promise.allSettled([
      this.prisma.$queryRaw`SELECT 1`,
      this.redis.ping(),
    ]);
    return {
      status: db.status === 'fulfilled' && cache.status === 'fulfilled' ? 'ok' : 'degraded',
      db: db.status,
      redis: cache.status,
      ts: Date.now(),
    };
  }
}
