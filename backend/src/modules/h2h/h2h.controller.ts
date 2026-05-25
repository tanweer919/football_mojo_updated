import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { H2HStatus } from '@prisma/client';
import { CurrentUser } from '../auth/current-user.decorator';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { H2HService } from './h2h.service';

@Controller({ path: 'h2h', version: '1' })
@UseGuards(FirebaseAuthGuard)
export class H2HController {
  constructor(private readonly h2h: H2HService) {}

  @Post()
  propose(
    @CurrentUser('uid') uid: string,
    @Body() body: { opponentId: string; gameweekId: string; message?: string },
  ) {
    return this.h2h.propose(uid, body.opponentId, body.gameweekId, body.message);
  }

  @Post(':id/accept')
  accept(@CurrentUser('uid') uid: string, @Param('id') id: string) {
    return this.h2h.respond(id, uid, 'ACCEPTED');
  }

  @Post(':id/decline')
  decline(@CurrentUser('uid') uid: string, @Param('id') id: string) {
    return this.h2h.respond(id, uid, 'DECLINED');
  }

  @Post(':id/cancel')
  cancel(@CurrentUser('uid') uid: string, @Param('id') id: string) {
    return this.h2h.cancel(id, uid);
  }

  @Get()
  list(@CurrentUser('uid') uid: string, @Query('status') status?: H2HStatus) {
    return this.h2h.listMine(uid, status);
  }
}
