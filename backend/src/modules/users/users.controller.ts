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

class FcmTokenBody {
  @IsString()
  @Length(8, 4096)
  token!: string;
}

class SupportedCountryBody {
  @IsString()
  @Length(0, 4)
  supportedCountryCode!: string;
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

  /// Register an FCM token against the signed-in user so the server can
  /// push 1v1 / lineup / scoring notifications via `sendToTokens`.
  /// Idempotent — duplicate tokens are silently de-duped server-side.
  @UseGuards(FirebaseAuthGuard)
  @Post('me/fcm-tokens')
  @HttpCode(204)
  async addFcmToken(
    @CurrentUser('uid') uid: string,
    @Body() body: FcmTokenBody,
  ) {
    await this.users.addFcmToken(uid, body.token);
  }

  /// Remove an FCM token (called on sign-out or token refresh).
  @UseGuards(FirebaseAuthGuard)
  @Delete('me/fcm-tokens/:token')
  @HttpCode(204)
  async removeFcmToken(
    @CurrentUser('uid') uid: string,
    @Param('token') token: string,
  ) {
    await this.users.removeFcmToken(uid, token);
  }

  /// Set the country the user supports during the World Cup.
  /// Pass empty string to clear.
  @UseGuards(FirebaseAuthGuard)
  @Patch('me/supported-country')
  async setSupportedCountry(
    @CurrentUser('uid') uid: string,
    @Body() body: SupportedCountryBody,
  ) {
    return this.users.setSupportedCountry(
      uid,
      body.supportedCountryCode === '' ? null : body.supportedCountryCode,
    );
  }

  /// Read notification opt-ins. Absent row → everything-on defaults.
  @UseGuards(FirebaseAuthGuard)
  @Get('me/notification-preferences')
  notificationPreferences(@CurrentUser('uid') uid: string) {
    return this.users.getNotificationPreferences(uid);
  }

  /// Patch notification opt-ins. Body is a partial — only sent flags change.
  @UseGuards(FirebaseAuthGuard)
  @Patch('me/notification-preferences')
  async setNotificationPreferences(
    @CurrentUser('uid') uid: string,
    @Body() body: Record<string, boolean>,
  ) {
    // Whitelist the known categories so a malicious client can't write
    // arbitrary columns into the preference row.
    const allowed = [
      'matchGoals', 'matchKickoff', 'matchFulltime', 'matchLineup',
      'breakingNews', 'wcDailyRecap',
      'fantasyResults', 'h2hInvites', 'h2hResults', 'cardDrops',
    ];
    const patch: Record<string, boolean> = {};
    for (const key of allowed) {
      if (typeof body[key] === 'boolean') patch[key] = body[key];
    }
    return this.users.setNotificationPreferences(uid, patch);
  }

  /// Paginated in-app notification history. Drives the notification
  /// center screen. Reads are not implicit — call /read separately.
  @UseGuards(FirebaseAuthGuard)
  @Get('me/notifications')
  notifications(
    @CurrentUser('uid') uid: string,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
  ) {
    return this.users.notificationHistory(uid, limit ? +limit : 30, cursor);
  }

  /// Unread count — for the home appbar bell badge.
  @UseGuards(FirebaseAuthGuard)
  @Get('me/notifications/unread-count')
  unreadCount(@CurrentUser('uid') uid: string) {
    return this.users.unreadNotificationCount(uid);
  }

  /// Mark read. POST `{ ids: [...] }` for a subset, or `{ all: true }` to
  /// clear the badge in one shot.
  @UseGuards(FirebaseAuthGuard)
  @Post('me/notifications/read')
  markRead(
    @CurrentUser('uid') uid: string,
    @Body() body: { ids?: string[]; all?: boolean },
  ) {
    return this.users.markNotificationsRead(
      uid,
      body.all === true ? null : (body.ids ?? []),
    );
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
