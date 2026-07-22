import { Inject, Injectable, Logger, OnModuleInit } from '@nestjs/common';
import Redis from 'ioredis';
import { PrismaService } from '../../common/prisma.service';
import { REDIS_PUB, REDIS_SUB } from '../../common/redis.module';
import { FirebaseAdminService } from '../auth/firebase-admin.service';

/**
 * Listens to the same Redis pub/sub channels the WebSocket gateway uses
 * (`match:{id}:update`, `match:{id}:event`) and fans out FCM topic messages.
 *
 * Topics:
 *   - team_{teamId}             → goals, kickoff, FT for that team
 *   - match_{matchId}           → users who opted into a specific match
 *   - team_{teamId}_lineup      → confirmed XI announcement (future)
 *
 * Data-only payloads so the client renders via flutter_local_notifications
 * and we own the channel/priority/grouping.
 */
@Injectable()
export class NotificationsDispatcher implements OnModuleInit {
  private readonly log = new Logger(NotificationsDispatcher.name);

  constructor(
    @Inject(REDIS_SUB) private readonly sub: Redis,
    @Inject(REDIS_PUB) private readonly redis: Redis,
    private readonly fcm: FirebaseAdminService,
    private readonly prisma: PrismaService,
  ) {}

  /// Exactly-once across the cluster: the first caller to set `key` wins and
  /// sends; duplicate publishes (or extra worker replicas all subscribed to the
  /// same Redis channels) get `null` and skip. TTL covers a full match.
  private async claimOnce(key: string, ttlSeconds = 6 * 60 * 60): Promise<boolean> {
    const won = await this.redis.set(key, '1', 'EX', ttlSeconds, 'NX');
    return won === 'OK';
  }

  async onModuleInit() {
    if (process.env.WORKER_MODE !== 'true') {
      // Single dispatcher across the cluster — keep it on the worker only.
      return;
    }
    await this.sub.psubscribe('match:*:update', 'match:*:event');
    this.sub.on('pmessage', (_pattern, channel, message) => {
      this.handle(channel, JSON.parse(message)).catch((err) =>
        this.log.error(`dispatch failed: ${(err as Error).message}`),
      );
    });
    this.log.log('FCM dispatcher listening on match:*:update / match:*:event');
  }

  private async handle(channel: string, payload: Record<string, unknown>) {
    const [, matchId, kind] = channel.split(':');
    const match = await this.prisma.match.findUnique({
      where: { id: matchId },
      include: { homeTeam: true, awayTeam: true },
    });
    if (!match) return;

    if (kind === 'event') {
      // Synthesised event from scores poller (currently only GOAL).
      const type = String(payload.type ?? '');
      if (type !== 'GOAL' && type !== 'RED') return;
      const scoringTeamId = String(payload.teamId ?? '');
      const scoringTeam = scoringTeamId === match.homeTeam.id ? match.homeTeam : match.awayTeam;
      const otherTeam   = scoringTeamId === match.homeTeam.id ? match.awayTeam : match.homeTeam;
      const title = type === 'GOAL'
        ? `⚽ ${scoringTeam.shortName ?? scoringTeam.name} ${match.homeScore}-${match.awayScore} ${otherTeam.shortName ?? otherTeam.name}`
        : `🟥 Red card · ${scoringTeam.shortName ?? scoringTeam.name}`;
      const body = type === 'GOAL'
        ? `${payload.minute ?? ''}' Goal`
        : `${scoringTeam.name} down to 10`;
      const data = {
        type, matchId,
        teamId: scoringTeamId,
        homeScore: String(match.homeScore),
        awayScore: String(match.awayScore),
        deepLink: `footballmojo://matches/${matchId}`,
      };

      // Per-team and per-match topics. FCM auto-dedupes for users on both.
      await Promise.allSettled([
        this.fcm.sendToTopic(`match_${matchId}`,   { title, body }, data),
        this.fcm.sendToTopic(`team_${scoringTeamId}`, { title, body }, data),
      ]);
      return;
    }

    if (kind === 'update') {
      // Kickoff and FT transitions only — not every minute update.
      const status = String(payload.status ?? '');
      const minute = typeof payload.minute === 'number' ? payload.minute : 0;
      if (status === 'LIVE' && minute <= 1) {
        const title = `Kick-off · ${match.homeTeam.shortName ?? match.homeTeam.name} vs ${match.awayTeam.shortName ?? match.awayTeam.name}`;
        await Promise.allSettled([
          this.fcm.sendToTopic(`match_${matchId}`, { title, body: 'Match started' }),
          this.fcm.sendToTopic(`team_${match.homeTeam.id}`, { title, body: 'Match started' }),
          this.fcm.sendToTopic(`team_${match.awayTeam.id}`, { title, body: 'Match started' }),
        ]);
        return;
      }
      if (status === 'FINISHED') {
        const title = `Full-time · ${match.homeTeam.shortName ?? match.homeTeam.name} ${match.homeScore}-${match.awayScore} ${match.awayTeam.shortName ?? match.awayTeam.name}`;
        await Promise.allSettled([
          this.fcm.sendToTopic(`match_${matchId}`, { title, body: 'Final whistle' }),
          this.fcm.sendToTopic(`team_${match.homeTeam.id}`, { title, body: 'Final whistle' }),
          this.fcm.sendToTopic(`team_${match.awayTeam.id}`, { title, body: 'Final whistle' }),
        ]);
      }
    }
  }
}
