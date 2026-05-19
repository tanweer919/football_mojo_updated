import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { IsString, Length } from 'class-validator';
import { CurrentUser } from '../auth/current-user.decorator';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { UsersService } from './users.service';

class ClaimTagBody {
  @IsString()
  @Length(3, 20)
  userTag!: string;
}

@Controller({ path: 'users', version: '1' })
export class UsersController {
  constructor(private readonly users: UsersService) {}

  // ─── Authenticated routes ────────────────────────────────────────────────
  @UseGuards(FirebaseAuthGuard)
  @Get('me')
  me(@CurrentUser('uid') uid: string) {
    return this.users.me(uid);
  }

  /// Claim or update the signed-in user's public handle.
  /// Body: `{ "userTag": "jordan42" }`.
  @UseGuards(FirebaseAuthGuard)
  @Patch('me/tag')
  claimTag(@CurrentUser('uid') uid: string, @Body() body: ClaimTagBody) {
    return this.users.claimUserTag(uid, body.userTag);
  }

  /// Mark the welcome-card reveal as seen so /me stops returning it.
  @UseGuards(FirebaseAuthGuard)
  @Post('me/welcome-card/dismiss')
  @HttpCode(204)
  async dismissWelcome(@CurrentUser('uid') uid: string) {
    await this.users.dismissWelcomeCard(uid);
  }

  /// Follow a team. The mobile app calls this from the "pick your teams"
  /// picker on first home-screen visit and any time the user toggles a
  /// crest in the picker. Idempotent — re-following a team is a no-op.
  @UseGuards(FirebaseAuthGuard)
  @Post('me/follow/:teamId')
  @HttpCode(204)
  async follow(@CurrentUser('uid') uid: string, @Param('teamId') teamId: string) {
    await this.users.followTeam(uid, teamId);
  }

  /// Unfollow a team. 204 whether the team was followed or not so the
  /// client doesn't need to read state before toggling.
  @UseGuards(FirebaseAuthGuard)
  @Delete('me/follow/:teamId')
  @HttpCode(204)
  async unfollow(@CurrentUser('uid') uid: string, @Param('teamId') teamId: string) {
    await this.users.unfollowTeam(uid, teamId);
  }

  // ─── Public read routes ──────────────────────────────────────────────────
  // Search + by-tag are exposed without auth so unauthenticated users can
  // still discover other managers (handles + display names are public).

  /// `GET /v1/users/search?q=jor` — prefix lookup, 20-row cap.
  @Get('search')
  search(@Query('q') q?: string) {
    return this.users.search(q ?? '');
  }

  /// `GET /v1/users/by-tag/jordan42` — exact-tag lookup, 404 if unclaimed.
  @Get('by-tag/:tag')
  byTag(@Param('tag') tag: string) {
    return this.users.findByTag(tag);
  }
}
