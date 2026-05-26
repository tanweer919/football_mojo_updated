import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PredictionsService } from './predictions.service';

/**
 * Idempotent bracket re-scoring. Walks every bracket in the WC2026
 * competition and re-derives `pointsAwarded` from the latest group
 * standings + final result.
 *
 * Runs every 5 minutes while in WORKER_MODE. Cheap: a single query for
 * groups + standings, an in-memory loop over brackets, conditional UPDATEs
 * only when totals change. No upstream API calls.
 *
 * Side-effects:
 *  - PredictionsService.scoreBracket also credits gems for newly-correct
 *    picks via GemsService, dedupe-protected by (userId, source, bracket:slot).
 *    So bracket gem rewards drip in as the tournament unfolds.
 */
@Injectable()
export class BracketScoringWorker {
  private readonly log = new Logger(BracketScoringWorker.name);
  private readonly isWorker: boolean;
  // The competitions we re-score every tick. Today: WC2026. Other tournaments
  // can be added here without code changes elsewhere.
  private readonly competitions = ['WC2026'];

  constructor(
    cfg: ConfigService,
    private readonly predictions: PredictionsService,
  ) {
    this.isWorker =
      process.env.WORKER_MODE === 'true' ||
      cfg.get<string>('NODE_ENV') !== 'production';
  }

  @Cron('*/5 * * * *', { name: 'bracket-scoring-tick' })
  async tick() {
    if (!this.isWorker) return;
    for (const competitionId of this.competitions) {
      try {
        const result = await this.predictions.scoreBracket(competitionId);
        if (result.updated > 0) {
          this.log.log(
            `bracket re-score: ${competitionId} → ${result.updated}/${result.scored} brackets updated`,
          );
        }
      } catch (err) {
        this.log.error(
          `bracket re-score failed for ${competitionId}: ${(err as Error).message}`,
        );
      }
    }
  }
}
