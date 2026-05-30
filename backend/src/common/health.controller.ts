import { Controller, Get, HttpCode, HttpException, HttpStatus, Inject, VERSION_NEUTRAL } from '@nestjs/common';
import Redis from 'ioredis';
import { PrismaService } from './prisma.service';
import { REDIS_PUB } from './redis.module';

@Controller({ path: 'health', version: VERSION_NEUTRAL })
export class HealthController {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(REDIS_PUB) private readonly redis: Redis,
  ) {}

  /// Liveness + readiness. Returns 200 when DB + Redis are reachable,
  /// 503 with a JSON body when either is down. Docker/Traefik treat the
  /// 503 as unhealthy and stop routing traffic to this replica.
  @Get()
  async check() {
    const [db, cache] = await Promise.allSettled([
      this.prisma.$queryRaw`SELECT 1`,
      this.redis.ping(),
    ]);
    const ok = db.status === 'fulfilled' && cache.status === 'fulfilled';
    const body = {
      status: ok ? 'ok' : 'degraded',
      db: db.status,
      redis: cache.status,
      ts: Date.now(),
    };
    if (!ok) {
      throw new HttpException(body, HttpStatus.SERVICE_UNAVAILABLE);
    }
    return body;
  }

  /// Cheap liveness — no dependency check. For container-runtime liveness
  /// probes that should NOT restart on a flaky DB blip. Use this when you
  /// only care "is the Node process alive?".
  @Get('liveness')
  @HttpCode(HttpStatus.OK)
  liveness() {
    return { status: 'ok', ts: Date.now() };
  }
}
