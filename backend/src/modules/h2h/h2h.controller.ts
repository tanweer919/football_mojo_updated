import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { H2HStatus } from '@prisma/client';
import { CurrentUser } from '../auth/current-user.decorator';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { H2HService } from './h2h.service';

@Controller({ path: 'h2h', version: '1' })
export class H2HController {
  constructor(private readonly h2h: H2HService) {}

  // Public — invite previews must work before sign-in so deep links resolve.
  @Get('invite/:token')
  invite(@Param('token') token: string) {
    return this.h2h.invitePreview(token);
  }

  // Public — ladder is read-only and meant to be shareable.
  @Get('ladder')
  ladder(@Query('tournamentId') tournamentId?: string) {
    return this.h2h.publicLadder(tournamentId);
  }

  @UseGuards(FirebaseAuthGuard)
  @Post('invite/:token/accept')
  redeem(@CurrentUser('uid') uid: string, @Param('token') token: string) {
    return this.h2h.acceptInvite(token, uid);
  }

  @UseGuards(FirebaseAuthGuard)
  @Post()
  propose(
    @CurrentUser('uid') uid: string,
    @Body() body: { opponentId?: string; gameweekId: string; message?: string },
  ) {
    return this.h2h.propose(uid, body.opponentId, body.gameweekId, body.message);
  }

  @UseGuards(FirebaseAuthGuard)
  @Post(':id/accept')
  accept(@CurrentUser('uid') uid: string, @Param('id') id: string) {
    return this.h2h.respond(id, uid, 'ACCEPTED');
  }

  @UseGuards(FirebaseAuthGuard)
  @Post(':id/decline')
  decline(@CurrentUser('uid') uid: string, @Param('id') id: string) {
    return this.h2h.respond(id, uid, 'DECLINED');
  }

  @UseGuards(FirebaseAuthGuard)
  @Post(':id/cancel')
  cancel(@CurrentUser('uid') uid: string, @Param('id') id: string) {
    return this.h2h.cancel(id, uid);
  }

  @UseGuards(FirebaseAuthGuard)
  @Get()
  list(@CurrentUser('uid') uid: string, @Query('status') status?: H2HStatus) {
    return this.h2h.listMine(uid, status);
  }
}
