import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../../common/prisma.service';
import { PushService } from './push.service';

/// Daily World Cup recap push.
///
/// Sent three times per day — one for each major timezone band — so the
/// digest lands roughly at breakfast everywhere without needing per-user
/// timezones in the DB. Bands + topics:
///   - 23:00 UTC → 09:00 Asia (Dubai/Karachi/Kolkata) → `wc_digest_asia`
///   - 07:00 UTC → 09:00 Europe (London/Berlin)        → `wc_digest_europe`
///   - 13:00 UTC → 09:00 Americas (Mexico/NYC)         → `wc_digest_americas`
///
/// The body is the same content; Flutter subscribes to whichever topic
/// matches the device's current timezone offset.
@Injectable()
export class WcDigestWorker {
  private readonly log = new Logger(WcDigestWorker.name);
  private readonly isWorker: boolean;
  private readonly competitionId = 'WC2026';

  constructor(
    cfg: ConfigService,
    private readonly prisma: PrismaService,
    private readonly push: PushService,
  ) {
    this.isWorker =
      process.env.WORKER_MODE === 'true' ||
      cfg.get<string>('NODE_ENV') !== 'production';
  }

  @Cron('0 23 * * *', { name: 'wc-digest-asia' })
  asiaTick() { return this.sendDigest('wc_digest_asia'); }

  @Cron('0 7 * * *',  { name: 'wc-digest-europe' })
  europeTick() { return this.sendDigest('wc_digest_europe'); }

  @Cron('0 13 * * *', { name: 'wc-digest-americas' })
  americasTick() { return this.sendDigest('wc_digest_americas'); }

  private async sendDigest(topic: string) {
    if (!this.isWorker) return;
    try {
      const summary = await this.buildSummary();
      if (!summary) {
        this.log.log(`digest skipped (${topic}): tournament not active`);
        return;
      }
      await this.push.pushToTopic(
        topic,
        { title: summary.title, body: summary.body },
        {
          category: 'wcDailyRecap',
          type: 'wc_daily_recap',
          deepLink: 'footballmojo://tournament',
        },
      );
      this.log.log(`digest fired → ${topic}: ${summary.title}`);
    } catch (err) {
      this.log.warn(`digest ${topic} failed: ${(err as Error).message}`);
    }
  }

  /// Builds the human-readable digest body. Returns null when there's no
  /// WC activity in the window (pre-tournament, off-day, post-tournament).
  private async buildSummary(): Promise<{ title: string; body: string } | null> {
    const now = new Date();
    const dayAgo = new Date(now.getTime() - 24 * 60 * 60_000);
    const dayAhead = new Date(now.getTime() + 24 * 60 * 60_000);

    const [played, upcoming, topScorer] = await Promise.all([
      // Matches finished in the last 24h.
      this.prisma.match.findMany({
        where: {
          competitionId: this.competitionId,
          status: 'FINISHED',
          kickoffAt: { gte: dayAgo },
        },
        include: { homeTeam: true, awayTeam: true },
        orderBy: { kickoffAt: 'desc' },
        take: 5,
      }),
      // Matches kicking off in the next 24h.
      this.prisma.match.findMany({
        where: {
          competitionId: this.competitionId,
          status: 'SCHEDULED',
          kickoffAt: { gte: now, lt: dayAhead },
        },
        include: { homeTeam: true, awayTeam: true },
        orderBy: { kickoffAt: 'asc' },
        take: 5,
      }),
      // Live top scorer — counted from MatchEvent.GOAL events in this comp.
      this.prisma.matchEvent.groupBy({
        by: ['playerId'],
        where: {
          type: 'GOAL',
          playerId: { not: null },
          match: { competitionId: this.competitionId },
        },
        _count: { _all: true },
        orderBy: { _count: { playerId: 'desc' } },
        take: 1,
      }),
    ]);

    if (!played.length && !upcoming.length) return null;

    // Title prioritises played results when they exist, otherwise teases
    // the day ahead.
    let title: string;
    if (played.length) {
      const top = played[0]!;
      title = `${top.homeTeam.shortName ?? top.homeTeam.name} ${top.homeScore}-${top.awayScore} ${top.awayTeam.shortName ?? top.awayTeam.name}`;
    } else {
      title = 'Today at the World Cup';
    }

    // Body composes a one-liner from the strongest available signal.
    const lines: string[] = [];
    if (played.length > 1) {
      lines.push(`${played.length} match${played.length === 1 ? '' : 'es'} yesterday.`);
    }
    if (upcoming.length) {
      const next = upcoming[0]!;
      lines.push(`Up next: ${next.homeTeam.shortName ?? next.homeTeam.name} vs ${next.awayTeam.shortName ?? next.awayTeam.name}.`);
    }
    if (topScorer.length && topScorer[0]!.playerId) {
      const goals = topScorer[0]!._count._all;
      const player = await this.prisma.player.findUnique({
        where: { id: topScorer[0]!.playerId! },
        select: { name: true },
      });
      if (player) {
        lines.push(`${player.name} leads with ${goals} goal${goals === 1 ? '' : 's'}.`);
      }
    }
    const body = lines.join(' ').slice(0, 240);
    return { title, body };
  }
}
