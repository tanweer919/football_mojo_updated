import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron, CronExpression } from '@nestjs/schedule';
import { Queue, Worker, JobsOptions } from 'bullmq';
import IORedis from 'ioredis';
import { PrismaService } from '../../common/prisma.service';
import { GlobalCupService } from '../global-cup/global-cup.service';
import { H2HService } from '../h2h/h2h.service';
import { FantasyScoringService } from './scoring.service';

const QUEUE_NAME = 'fantasy-scoring';

type Job =
  | { kind: 'score-fixture';   matchId: string; gameweekId: string; reason: 'live' | 'final' }
  | { kind: 'score-gameweek';  gameweekId: string }
  | { kind: 'settle-h2h';      gameweekId: string }
  | { kind: 'settle-cup';      tournamentId: string };

/**
 * Reliable scoring pipeline.
 *
 * Three layers of safety:
 *  1. CRON heartbeat enqueues `score-fixture` for every LIVE fixture in a current
 *     gameweek every 60s. Updates are idempotent — duplicates are harmless.
 *  2. CRON closure pass: when a fixture transitions to FINISHED (status flips in
 *     our DB by the scores poller), the next cron tick enqueues a `final` job.
 *  3. CRON gameweek closure: 5 minutes after a gameweek's `endsAt`, enqueues
 *     `score-gameweek` (full pass, in case any fixture was missed) followed by
 *     `settle-h2h` for that gameweek.
 *
 * BullMQ gives us retries with exponential backoff, dead-letter, and concurrency
 * limits to stay under api-football's per-minute cap.
 */
@Injectable()
export class FantasyScoringWorker implements OnModuleInit {
  private readonly log = new Logger(FantasyScoringWorker.name);
  private queue!: Queue<Job>;
  private worker!: Worker<Job>;
  private connection!: IORedis;
  private isWorker: boolean;

  constructor(
    cfg: ConfigService,
    private readonly prisma: PrismaService,
    private readonly scoring: FantasyScoringService,
    private readonly h2h: H2HService,
    private readonly cup: GlobalCupService,
  ) {
    this.isWorker = process.env.WORKER_MODE === 'true' || cfg.get<string>('NODE_ENV') !== 'production';
    this.connection = new IORedis(cfg.getOrThrow<string>('REDIS_URL'), { maxRetriesPerRequest: null });
  }

  onModuleInit() {
    this.queue = new Queue<Job>(QUEUE_NAME, { connection: this.connection });
    if (!this.isWorker) return;

    this.worker = new Worker<Job>(
      QUEUE_NAME,
      async (job) => this.dispatch(job.data),
      {
        connection: this.connection,
        concurrency: 4,                             // respect api-football per-minute cap
        autorun: true,
        removeOnComplete: { age: 3600, count: 1000 },
        removeOnFail:     { age: 86_400 },
      },
    );

    this.worker.on('completed', (job) => this.log.log(`done: ${job.name} ${JSON.stringify(job.data)}`));
    this.worker.on('failed',    (job, err) => this.log.error(`failed: ${job?.name} — ${err.message}`));
  }

  // ─── Dispatch ─────────────────────────────────────────────────────────────
  private async dispatch(job: Job): Promise<void> {
    switch (job.kind) {
      case 'score-fixture':
        await this.scoring.scoreFixture(job.matchId, job.gameweekId);
        if (job.reason === 'final') {
          await this.scoring.rollupLineups(job.gameweekId);
        }
        return;
      case 'score-gameweek':
        await this.scoring.scoreGameweek(job.gameweekId);
        await this.enqueue({ kind: 'settle-h2h', gameweekId: job.gameweekId });
        return;
      case 'settle-h2h':
        await this.h2h.resolveForGameweek(job.gameweekId);
        return;
      case 'settle-cup':
        await this.cup.distributePrizes(job.tournamentId);
        return;
    }
  }

  private enqueue(job: Job, opts: JobsOptions = {}) {
    return this.queue.add(job.kind, job, {
      attempts: 5,
      backoff: { type: 'exponential', delay: 5_000 },
      jobId: this.makeJobId(job),                  // dedupe identical inflight work
      removeOnComplete: { age: 3600 },
      removeOnFail: { age: 86_400 },
      ...opts,
    });
  }

  private makeJobId(job: Job): string {
    switch (job.kind) {
      case 'score-fixture':  return `fx:${job.matchId}:${job.reason}:${Math.floor(Date.now() / 60_000)}`;
      case 'score-gameweek': return `gw:${job.gameweekId}`;
      case 'settle-h2h':     return `h2h:${job.gameweekId}`;
      case 'settle-cup':     return `cup:${job.tournamentId}`;
    }
  }

  // ─── Triggers ──────────────────────────────────────────────────────────────

  /** Every 60s: enqueue score-fixture for each live match in an active gameweek. */
  @Cron(CronExpression.EVERY_MINUTE, { name: 'scoring-live-tick' })
  async liveTick() {
    if (!this.isWorker) return;
    const now = new Date();
    const activeGw = await this.prisma.fantasyGameweek.findFirst({
      where: { lockAt: { lte: now }, endsAt: { gte: now }, scored: false },
    });
    if (!activeGw) return;

    const live = await this.prisma.match.findMany({
      where: { id: { in: activeGw.matchIds }, status: { in: ['LIVE', 'HALF_TIME'] } },
      select: { id: true },
    });
    for (const m of live) {
      await this.enqueue({ kind: 'score-fixture', matchId: m.id, gameweekId: activeGw.id, reason: 'live' });
    }
  }

  /** Every 2 min: any FINISHED fixture in an active gameweek not yet finalised → final job. */
  @Cron('*/2 * * * *', { name: 'scoring-final-tick' })
  async finalTick() {
    if (!this.isWorker) return;
    const now = new Date();
    const gws = await this.prisma.fantasyGameweek.findMany({
      where: { lockAt: { lte: now }, endsAt: { gte: new Date(now.getTime() - 6 * 60 * 60_000) } },
    });
    for (const gw of gws) {
      const finished = await this.prisma.match.findMany({
        where: { id: { in: gw.matchIds }, status: 'FINISHED' },
        select: { id: true },
      });
      for (const m of finished) {
        await this.enqueue({ kind: 'score-fixture', matchId: m.id, gameweekId: gw.id, reason: 'final' });
      }
    }
  }

  /** Every 5 min: gameweeks whose endsAt has passed but aren't marked scored → score-gameweek. */
  @Cron('*/5 * * * *', { name: 'scoring-gameweek-close' })
  async gameweekClosure() {
    if (!this.isWorker) return;
    const closedGws = await this.prisma.fantasyGameweek.findMany({
      where: { endsAt: { lte: new Date() }, scored: false },
    });
    for (const gw of closedGws) {
      await this.enqueue({ kind: 'score-gameweek', gameweekId: gw.id });
    }
  }

  /** Every hour: tournaments whose endsAt has passed → distribute prizes (idempotent). */
  @Cron('0 * * * *', { name: 'scoring-cup-settle' })
  async cupSettlement() {
    if (!this.isWorker) return;
    const ended = await this.prisma.fantasyTournament.findMany({
      where: { endsAt: { lte: new Date() } },
      include: { prizes: { where: { awarded: false } } },
    });
    for (const t of ended) {
      if (t.prizes.length) {
        await this.enqueue({ kind: 'settle-cup', tournamentId: t.id });
      }
    }
  }

  /** Admin hook: re-score a specific fixture (handles upstream corrections). */
  async rescoreFixture(matchId: string, gameweekId: string) {
    await this.enqueue({ kind: 'score-fixture', matchId, gameweekId, reason: 'final' });
  }
}
