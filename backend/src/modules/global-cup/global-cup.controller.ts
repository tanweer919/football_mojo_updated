import { CacheInterceptor, CacheTTL } from '@nestjs/cache-manager';
import { Controller, Get, Param, Query, UseGuards, UseInterceptors } from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { GlobalCupService } from './global-cup.service';

@Controller({ path: 'global-cup', version: '1' })
@UseInterceptors(CacheInterceptor)
export class GlobalCupController {
  constructor(private readonly cup: GlobalCupService) {}

  @Get(':tournamentId/leaderboard')
  @CacheTTL(30_000)
  leaderboard(@Param('tournamentId') id: string, @Query('limit') limit?: string) {
    return this.cup.cumulativeLeaderboard(id, limit ? +limit : 1000);
  }

  @Get(':tournamentId/prizes')
  @CacheTTL(300_000)
  prizes(@Param('tournamentId') id: string) {
    return this.cup.listPrizes(id);
  }

  @UseGuards(FirebaseAuthGuard)
  @Get(':tournamentId/me')
  me(@Param('tournamentId') id: string, @CurrentUser('uid') uid: string) {
    return this.cup.myRank(id, uid);
  }
}
