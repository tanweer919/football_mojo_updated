import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { GemSource, Prisma } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';

/** Canonical gem economy. Single source of truth for amounts. */
export const GEM_RULES = {
  // Earn ▼
  predictionResult: 3,        // correct outcome
  predictionExact: 10,        // exact score
  bracketGroupWinner: 15,     // per correct 1st place
  bracketRunnerUp: 5,         // per correct 2nd place
  bracketR16Reach: 15,        // per correct "reached R16" pick
  bracketQfReach: 30,         // per correct "reached QF" pick
  bracketSfReach: 60,         // per correct "reached SF" pick
  bracketFinalist: 100,       // per correct "reached final" pick
  bracketChampion: 500,       // correct champion (bumped — biggest WC moment)
  dailyLogin: 5,              // once per UTC day
  fantasyTier: {              // by gameweek rank
    top1: 500,
    top10: 200,
    top100: 50,
    top1000: 10,
  },
  // Spend ▼ (catalog kept here so controllers can quote prices)
  packs: {
    bronze:    200,
    silver:    500,
    gold:      1500,
  },
  profileFlair: 300,
  captainReroll: 150,
} as const;

export type PackTier = keyof typeof GEM_RULES.packs;

@Injectable()
export class GemsService {
  private readonly log = new Logger(GemsService.name);
  constructor(private readonly prisma: PrismaService) {}

  // ───────────────────────────────────────────────────────────────────────
  // Core credit / debit. Both use a serializable transaction and a unique
  // (userId, source, refType, refId) dedupe so re-runs are idempotent.
  // ───────────────────────────────────────────────────────────────────────

  async credit(input: {
    userId: string;
    amount: number;
    source: GemSource;
    description?: string;
    refType?: string;
    refId?: string;
  }): Promise<{ balance: number; credited: boolean }> {
    if (input.amount <= 0) throw new BadRequestException('amount_must_be_positive');
    return this._move({ ...input, amount: input.amount });
  }

  async debit(input: {
    userId: string;
    amount: number;
    source: GemSource;
    description?: string;
    refType?: string;
    refId?: string;
  }): Promise<{ balance: number; credited: boolean }> {
    if (input.amount <= 0) throw new BadRequestException('amount_must_be_positive');
    return this._move({ ...input, amount: -input.amount });
  }

  private async _move(input: {
    userId: string;
    amount: number;            // signed
    source: GemSource;
    description?: string;
    refType?: string;
    refId?: string;
  }): Promise<{ balance: number; credited: boolean }> {
    return this.prisma.$transaction(
      async (tx) => {
        // Dedupe: if a (user, source, refType, refId) tuple already exists,
        // skip silently and return the current balance. Lets scorers be
        // re-run safely.
        if (input.refType || input.refId) {
          const dupe = await tx.gemTransaction.findFirst({
            where: {
              userId: input.userId,
              source: input.source,
              refType: input.refType ?? null,
              refId: input.refId ?? null,
            },
            select: { id: true },
          });
          if (dupe) {
            const u = await tx.user.findUnique({
              where: { id: input.userId },
              select: { gems: true },
            });
            return { balance: u?.gems ?? 0, credited: false };
          }
        }

        const user = await tx.user.findUnique({
          where: { id: input.userId },
          select: { gems: true },
        });
        if (!user) throw new NotFoundException('user_not_found');

        const next = user.gems + input.amount;
        if (next < 0) throw new ConflictException('insufficient_gems');

        await tx.user.update({
          where: { id: input.userId },
          data: { gems: next },
        });
        await tx.gemTransaction.create({
          data: {
            userId: input.userId,
            amount: input.amount,
            source: input.source,
            description: input.description,
            refType: input.refType,
            refId: input.refId,
            balanceAfter: next,
          },
        });
        return { balance: next, credited: true };
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.Serializable, timeout: 8_000 },
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Earn shortcuts — call sites in PredictionsService, FantasyScoringService.
  // ───────────────────────────────────────────────────────────────────────

  async creditPredictionPoints(
    userId: string,
    predictionId: string,
    points: number,
  ): Promise<void> {
    if (points >= 10) {
      await this.credit({
        userId,
        amount: GEM_RULES.predictionExact,
        source: 'PREDICTION_EXACT',
        description: 'Exact-score prediction',
        refType: 'prediction',
        refId: predictionId,
      });
    } else if (points >= 3) {
      await this.credit({
        userId,
        amount: GEM_RULES.predictionResult,
        source: 'PREDICTION_CORRECT',
        description: 'Correct result prediction',
        refType: 'prediction',
        refId: predictionId,
      });
    }
  }

  async creditFantasyRank(
    userId: string,
    lineupId: string,
    rank: number,
  ): Promise<void> {
    let amount = 0;
    if (rank === 1) amount = GEM_RULES.fantasyTier.top1;
    else if (rank <= 10) amount = GEM_RULES.fantasyTier.top10;
    else if (rank <= 100) amount = GEM_RULES.fantasyTier.top100;
    else if (rank <= 1000) amount = GEM_RULES.fantasyTier.top1000;
    if (!amount) return;
    await this.credit({
      userId,
      amount,
      source: 'FANTASY_RANK',
      description: `Gameweek rank #${rank}`,
      refType: 'lineup',
      refId: lineupId,
    });
  }

  async creditBracket(
    userId: string,
    bracketId: string,
    slot: string,
    kind:
      | 'group_winner'
      | 'runner_up'
      | 'r16_reach'
      | 'qf_reach'
      | 'sf_reach'
      | 'finalist'
      | 'champion',
  ): Promise<void> {
    const map = {
      group_winner: { amount: GEM_RULES.bracketGroupWinner, source: 'BRACKET_GROUP_WINNER' as GemSource },
      runner_up:    { amount: GEM_RULES.bracketRunnerUp,    source: 'BRACKET_RUNNER_UP'    as GemSource },
      r16_reach:    { amount: GEM_RULES.bracketR16Reach,    source: 'BRACKET_R16_REACH'    as GemSource },
      qf_reach:     { amount: GEM_RULES.bracketQfReach,     source: 'BRACKET_QF_REACH'     as GemSource },
      sf_reach:     { amount: GEM_RULES.bracketSfReach,     source: 'BRACKET_SF_REACH'     as GemSource },
      finalist:     { amount: GEM_RULES.bracketFinalist,    source: 'BRACKET_FINALIST'     as GemSource },
      champion:     { amount: GEM_RULES.bracketChampion,    source: 'BRACKET_CHAMPION'     as GemSource },
    }[kind];
    await this.credit({
      userId,
      amount: map.amount,
      source: map.source,
      description: `Bracket ${slot}`,
      refType: 'bracket',
      refId: `${bracketId}:${slot}`,
    });
  }

  // ───────────────────────────────────────────────────────────────────────
  // Daily login
  // ───────────────────────────────────────────────────────────────────────

  async claimDaily(userId: string): Promise<{ balance: number; awarded: number; nextClaimAt: Date }> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { lastDailyClaimAt: true, gems: true },
    });
    if (!user) throw new NotFoundException('user_not_found');

    const now = new Date();
    const todayKey = now.toISOString().slice(0, 10); // YYYY-MM-DD (UTC)
    const lastKey = user.lastDailyClaimAt?.toISOString().slice(0, 10);
    const tomorrow = new Date(Date.UTC(
      now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1,
    ));
    if (lastKey === todayKey) {
      return { balance: user.gems, awarded: 0, nextClaimAt: tomorrow };
    }
    const res = await this.credit({
      userId,
      amount: GEM_RULES.dailyLogin,
      source: 'DAILY_LOGIN',
      description: 'Daily login',
      refType: 'daily',
      refId: todayKey,
    });
    await this.prisma.user.update({
      where: { id: userId },
      data: { lastDailyClaimAt: now },
    });
    return { balance: res.balance, awarded: GEM_RULES.dailyLogin, nextClaimAt: tomorrow };
  }

  // ───────────────────────────────────────────────────────────────────────
  // Read APIs
  // ───────────────────────────────────────────────────────────────────────

  async balance(userId: string): Promise<{ balance: number; canClaimDaily: boolean }> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { gems: true, lastDailyClaimAt: true },
    });
    if (!user) throw new NotFoundException('user_not_found');
    const todayKey = new Date().toISOString().slice(0, 10);
    const lastKey = user.lastDailyClaimAt?.toISOString().slice(0, 10);
    return { balance: user.gems, canClaimDaily: lastKey !== todayKey };
  }

  async history(userId: string, limit = 50, cursor?: string) {
    const rows = await this.prisma.gemTransaction.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    });
    const hasMore = rows.length > limit;
    const sliced = hasMore ? rows.slice(0, limit) : rows;
    return {
      rows: sliced.map((r) => ({
        id: r.id,
        amount: r.amount,
        source: r.source,
        description: r.description,
        refType: r.refType,
        refId: r.refId,
        balanceAfter: r.balanceAfter,
        createdAt: r.createdAt,
      })),
      nextCursor: hasMore ? sliced[sliced.length - 1]!.id : null,
    };
  }

  /** Catalog of spend prices — surfaced to the client for the wallet UI. */
  catalog() {
    return {
      packs: GEM_RULES.packs,
      profileFlair: GEM_RULES.profileFlair,
      captainReroll: GEM_RULES.captainReroll,
      earnRules: {
        predictionResult: GEM_RULES.predictionResult,
        predictionExact: GEM_RULES.predictionExact,
        bracketGroupWinner: GEM_RULES.bracketGroupWinner,
        bracketRunnerUp: GEM_RULES.bracketRunnerUp,
        bracketR16Reach: GEM_RULES.bracketR16Reach,
        bracketQfReach: GEM_RULES.bracketQfReach,
        bracketSfReach: GEM_RULES.bracketSfReach,
        bracketFinalist: GEM_RULES.bracketFinalist,
        bracketChampion: GEM_RULES.bracketChampion,
        dailyLogin: GEM_RULES.dailyLogin,
        fantasy: GEM_RULES.fantasyTier,
      },
    };
  }
}
