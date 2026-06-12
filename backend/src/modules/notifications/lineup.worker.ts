import { Inject, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron, CronExpression } from '@nestjs/schedule';
import Redis from 'ioredis';
import { PrismaService } from '../../common/prisma.service';
import { REDIS_PUB } from '../../common/redis.module';
import { ApiFootballCacheService } from '../api-football/api-football-cache.service';
import { PushService } from './push.service';

/**
 * "Confirmed XI" push, ~1h before kickoff (condition 1).
 *
 * Every 5 minutes, looks at fixtures starting within the next ~75 min and polls
 * api-football lineups for each. The FIRST time a fixture's starting XI is
 * available, it pushes once to each team's `team_{id}_lineup` topic (followers
 * subscribe to that on follow). A Redis flag dedupes so a match is announced
 * only once, and a SET NX claim stops overlapping ticks from double-sending.
 *
 * Only runs on the worker node (single dispatcher across the cluster).
 */
@Injectable()
export class LineupWorker {
  private readonly log = new Logger(LineupWorker.name);
  private readonly isWorker: boolean;

  constructor(
    cfg: ConfigService,
    private readonly prisma: PrismaService,
    private readonly push: PushService,
    private readonly apiCache: ApiFootballCacheService,
    @Inject(REDIS_PUB) private readonly redis: Redis,
  ) {
    this.isWorker =
      process.env.WORKER_MODE === 'true' ||
      cfg.get<string>('NODE_ENV') !== 'production';
  }

  @Cron(CronExpression.EVERY_5_MINUTES, { name: 'lineup-announce' })
  async tick(): Promise<void> {
    if (!this.isWorker) return;
    const now = Date.now();
    const upcoming = await this.prisma.match.findMany({
      where: {
        status: 'SCHEDULED',
        kickoffAt: { gte: new Date(now), lte: new Date(now + 75 * 60_000) },
      },
      include: { homeTeam: true, awayTeam: true },
    });

    for (const m of upcoming) {
      // Lineups need the numeric api-football fixture id; seed placeholders
      // (WC2026-*) have none, and by kickoff the reconciled real row exists.
      if (!/^\d+$/.test(m.id)) continue;
      const key = `lineup:notified:${m.id}`;
      try {
        if (await this.redis.exists(key)) continue;
        const lineups = await this.apiCache.fixtureLineups(Number(m.id));
        const ready = lineups.some((l) => (l.startXI?.length ?? 0) > 0);
        if (!ready) continue; // not announced yet — a later tick retries

        // Claim it so overlapping ticks can't double-send.
        const won = await this.redis.set(key, '1', 'EX', 6 * 60 * 60, 'NX');
        if (won !== 'OK') continue;

        const title = `Confirmed XI · ${m.homeTeam.shortName ?? m.homeTeam.name} vs ${m.awayTeam.shortName ?? m.awayTeam.name}`;
        const data = {
          type: 'lineup',
          category: 'matchLineup',
          matchId: m.id,
          deepLink: `footballmojo://matches/${m.id}`,
        };
        await Promise.allSettled([
          this.push.pushToTopic(`team_${m.homeTeam.id}_lineup`, { title, body: 'Starting line-ups are in' }, data),
          this.push.pushToTopic(`team_${m.awayTeam.id}_lineup`, { title, body: 'Starting line-ups are in' }, data),
        ]);
        this.log.log(`lineup announced for ${m.id} (${m.homeTeam.name} vs ${m.awayTeam.name})`);
      } catch (e) {
        this.log.warn(`lineup check failed for ${m.id}: ${(e as Error).message}`);
      }
    }
  }
}
