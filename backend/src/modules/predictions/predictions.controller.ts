import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { PredictionsService } from './predictions.service';

@Controller({ path: 'predictions', version: '1' })
@UseGuards(FirebaseAuthGuard)
export class PredictionsController {
  constructor(private readonly predictions: PredictionsService) {}

  @Post('matches/:matchId')
  submit(
    @CurrentUser('uid') uid: string,
    @Param('matchId') matchId: string,
    @Body() body: { homeScore: number; awayScore: number },
  ) {
    return this.predictions.submit(uid, matchId, body.homeScore, body.awayScore);
  }

  @Get('mine')
  mine(@CurrentUser('uid') uid: string) {
    return this.predictions.myPredictions(uid);
  }

  @Get('leaderboard')
  leaderboard(@Query('competitionId') competitionId?: string) {
    return this.predictions.leaderboard(competitionId ? 'competition' : 'global', competitionId);
  }

  @Post('bracket')
  bracket(
    @CurrentUser('uid') uid: string,
    @Body() body: { competitionId: string; picks: Record<string, string> },
  ) {
    return this.predictions.submitBracket(uid, body.competitionId, body.picks);
  }

  @Get('bracket/me')
  async myBracket(
    @CurrentUser('uid') uid: string,
    @Query('competitionId') competitionId: string,
  ) {
    return (await this.predictions.getMyBracket(uid, competitionId)) ?? null;
  }

  @Get('bracket/leaderboard')
  bracketLeaderboard(@Query('competitionId') competitionId: string) {
    return this.predictions.bracketLeaderboard(competitionId);
  }
}
