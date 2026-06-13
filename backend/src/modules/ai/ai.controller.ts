import { Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { DailyDigestService } from './daily-digest.service';
import { MatchPreviewService } from './match-preview.service';

/// AI features. Auth-guarded (anonymous Firebase users included) so we can
/// attribute/limit usage; the heavy lifting is cached, so repeat taps and
/// other users for the same match are free.
@Controller({ path: 'ai', version: '1' })
@UseGuards(FirebaseAuthGuard)
export class AiController {
  constructor(
    private readonly preview: MatchPreviewService,
    private readonly daily: DailyDigestService,
  ) {}

  @Post('matches/:id/preview')
  matchPreview(@Param('id') id: string) {
    return this.preview.getPreview(id);
  }

  /// Home "matchday brief": today's preview + yesterday's recap. Cached per
  /// date, so one generation serves everyone.
  @Get('daily')
  dailyBrief() {
    return this.daily.getDaily();
  }
}
