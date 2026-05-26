import { Controller, Get, Post, Query, UseGuards } from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { GemsService } from './gems.service';

@Controller({ path: 'gems', version: '1' })
export class GemsController {
  constructor(private readonly gems: GemsService) {}

  // Public — exposes prices so the marketing surfaces can render them.
  @Get('catalog')
  catalog() {
    return this.gems.catalog();
  }

  @UseGuards(FirebaseAuthGuard)
  @Get('me')
  me(@CurrentUser('uid') uid: string) {
    return this.gems.balance(uid);
  }

  @UseGuards(FirebaseAuthGuard)
  @Get('history')
  history(
    @CurrentUser('uid') uid: string,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
  ) {
    return this.gems.history(uid, limit ? +limit : 50, cursor);
  }

  @UseGuards(FirebaseAuthGuard)
  @Post('daily')
  claimDaily(@CurrentUser('uid') uid: string) {
    return this.gems.claimDaily(uid);
  }
}
