import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { AwardType } from '@prisma/client';
import { CurrentUser } from '../auth/current-user.decorator';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { AwardsService } from './awards.service';

@Controller({ path: 'awards', version: '1' })
export class AwardsController {
  constructor(private readonly awards: AwardsService) {}

  // Public — candidates list doesn't require auth.
  @Get('candidates')
  candidates(
    @Query('competitionId') competitionId: string,
    @Query('awardType') awardType: AwardType,
    @Query('limit') limit?: string,
  ) {
    return this.awards.candidates(
      competitionId,
      awardType,
      limit ? +limit : 30,
    );
  }

  @UseGuards(FirebaseAuthGuard)
  @Get('mine')
  mine(
    @CurrentUser('uid') uid: string,
    @Query('competitionId') competitionId: string,
  ) {
    return this.awards.myPicks(uid, competitionId);
  }

  @UseGuards(FirebaseAuthGuard)
  @Post('picks')
  submit(
    @CurrentUser('uid') uid: string,
    @Body() body: {
      competitionId: string;
      awardType: AwardType;
      playerId: string;
    },
  ) {
    return this.awards.submitPick(
      uid, body.competitionId, body.awardType, body.playerId,
    );
  }
}
