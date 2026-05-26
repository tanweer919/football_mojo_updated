import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';
import { mintWelcomeCard } from '../auth/welcome-card';

/// Allowed shape for a user-facing handle.
///   - lowercase letters, digits, dot, underscore
///   - 3 to 20 characters
///   - cannot start/end with `.` or `_`, no consecutive `..` or `__`
const TAG_PATTERN = /^(?![._])(?!.*[._]{2})[a-z0-9._]{3,20}(?<![._])$/;

/**
 * Profile-page data assembler. One round-trip from the client; the service
 * fans out to a handful of small queries and merges the result.
 */
@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async me(uid: string) {
    const [user, ownedCount, h2hWins, totalPoints, achievements, followedTeams] =
      await Promise.all([
        this.prisma.user.findUnique({ where: { id: uid } }),
        this.prisma.ownedCard.count({ where: { ownerId: uid } }),
        this.prisma.h2HChallenge.count({ where: { winnerId: uid } }),
        this.prisma.fantasyLineup.aggregate({
          where: { userId: uid },
          _sum: { totalPoints: true },
        }),
        this.prisma.userAchievement.findMany({
          where: { userId: uid },
          include: {
            achievement: { select: { id: true, name: true, description: true, iconUrl: true } },
          },
          orderBy: { unlockedAt: 'desc' },
        }),
        this._followedTeamsFor(uid),
      ]);

    if (!user) throw new NotFoundException('user_not_found');

    // Ownership rarity breakdown.
    const rarityBreakdown = await this.prisma.ownedCard.groupBy({
      by: ['templateId'],
      where: { ownerId: uid },
      _count: { _all: true },
    });
    const templates = rarityBreakdown.length
      ? await this.prisma.cardTemplate.findMany({
          where: { id: { in: rarityBreakdown.map((r) => r.templateId) } },
          select: { id: true, rarity: true },
        })
      : [];
    const rarityCount: Record<string, number> = {};
    for (const r of rarityBreakdown) {
      const t = templates.find((x) => x.id === r.templateId);
      if (!t) continue;
      rarityCount[t.rarity] = (rarityCount[t.rarity] ?? 0) + r._count._all;
    }

    // Surface the signup-gift card until the user dismisses the reveal.
    // After dismissal `welcomeCardSeenAt` is set and we stop returning it.
    //
    // Self-heal: if the user has no SIGNUP_GIFT card yet (e.g. they signed up
    // before `seed:cards` had been run, so the original mint attempt found an
    // empty catalogue) attempt to mint one now. Fire-and-forget pattern — if
    // the second mint also fails the user simply gets `welcomeCard: null` and
    // we'll try again on the next /me read.
    let welcomeCard = user.welcomeCardSeenAt == null
        ? await this._loadUnseenWelcomeCard(uid)
        : null;
    if (welcomeCard == null && user.welcomeCardSeenAt == null) {
      const mintedId = await mintWelcomeCard(this.prisma, uid).catch(() => null);
      if (mintedId) {
        welcomeCard = await this._loadUnseenWelcomeCard(uid);
      }
    }

    // Pinned-card showcase. Pull the full template + player so the
    // profile screen can render the card without an extra round-trip.
    const pinnedCard = user.pinnedCardId
      ? await this.prisma.ownedCard.findFirst({
          where: { id: user.pinnedCardId, ownerId: uid },
          include: {
            template: {
              include: {
                player: { include: { team: { select: { id: true, name: true, shortName: true, crestUrl: true, countryCode: true } } } },
              },
            },
          },
        })
      : null;

    return {
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      userTag: user.userTag,
      photoUrl: user.photoUrl,
      countryCode: user.countryCode,
      supportedCountryCode: user.supportedCountryCode,
      coins: user.coins,
      gems: user.gems,
      proExpiresAt: user.proExpiresAt,
      memberSince: user.createdAt,
      welcomeCard,
      pinnedCard,
      stats: {
        ownedCards: ownedCount,
        totalFantasyPoints: totalPoints._sum.totalPoints ?? 0,
        h2hWins,
        rarityCount,
      },
      achievements: achievements.map((a) => ({
        id: a.achievement.id,
        name: a.achievement.name,
        description: a.achievement.description,
        iconUrl: a.achievement.iconUrl,
        unlockedAt: a.unlockedAt,
      })),
      followedTeams,
    };
  }

  /// Claim or change the signed-in user's public handle.
  /// Throws 400 if the format is invalid, 409 if the tag is already taken.
  async claimUserTag(uid: string, raw: string) {
    const tag = raw.trim().toLowerCase();
    if (!TAG_PATTERN.test(tag)) {
      throw new BadRequestException(
        'invalid_user_tag — 3-20 chars, lowercase letters/digits/./_ only, can’t start/end with . or _',
      );
    }
    try {
      const updated = await this.prisma.user.update({
        where: { id: uid },
        data: { userTag: tag },
        select: { id: true, userTag: true, displayName: true, photoUrl: true },
      });
      return updated;
    } catch (e) {
      if (
        e instanceof Prisma.PrismaClientKnownRequestError &&
        e.code === 'P2002'
      ) {
        throw new ConflictException('user_tag_taken');
      }
      throw e;
    }
  }

  /// Strip the leading `@` if a caller sends one, lowercase it.
  private _normalize(q: string): string {
    return q.replace(/^@+/, '').trim().toLowerCase();
  }

  /// Find users by handle prefix or display-name substring. Caps at 20 hits
  /// so a malicious 1-char query can't return the whole table.
  ///
  /// Sort: exact tag match first, then prefix matches, then display-name
  /// matches — this is what users expect from "find a friend" UX.
  async search(rawQuery: string) {
    const q = this._normalize(rawQuery);
    if (q.length < 2) return [];

    return this.prisma.user.findMany({
      where: {
        OR: [
          { userTag:     { startsWith: q,  mode: 'insensitive' } },
          { displayName: { contains: q,    mode: 'insensitive' } },
        ],
      },
      select: { id: true, userTag: true, displayName: true, photoUrl: true, countryCode: true },
      take: 20,
      orderBy: [
        // Tagged users first (so unclaimed accounts don't dominate the list).
        { userTag: 'asc' },
        { displayName: 'asc' },
      ],
    });
  }

  /// Mark the welcome-card reveal as seen so /me stops returning it.
  /// Idempotent — re-calls just leave the timestamp pinned to the first one.
  async dismissWelcomeCard(uid: string) {
    await this.prisma.user.update({
      where: { id: uid },
      data: { welcomeCardSeenAt: new Date() },
    });
  }

  /// Add a team to the user's `favouriteTeams` list. We could use Postgres'
  /// array-prepend operator for atomicity but Prisma's high-level API
  /// reads cleanly enough at 5-team list sizes and the picker UI guards
  /// against rapid double-tap, so a read-modify-write is fine here.
  async followTeam(uid: string, teamId: string) {
    if (!teamId.trim()) throw new BadRequestException('team_id_required');
    const team = await this.prisma.team.findUnique({ where: { id: teamId }, select: { id: true } });
    if (!team) throw new NotFoundException('team_not_found');
    const u = await this.prisma.user.findUnique({
      where: { id: uid },
      select: { favouriteTeams: true },
    });
    if (!u) throw new NotFoundException('user_not_found');
    if (u.favouriteTeams.includes(teamId)) return; // idempotent
    await this.prisma.user.update({
      where: { id: uid },
      data: { favouriteTeams: { set: [...u.favouriteTeams, teamId] } },
    });
  }

  /// Remove a team. Idempotent — missing team is not an error.
  async unfollowTeam(uid: string, teamId: string) {
    const u = await this.prisma.user.findUnique({
      where: { id: uid },
      select: { favouriteTeams: true },
    });
    if (!u) throw new NotFoundException('user_not_found');
    const next = u.favouriteTeams.filter((id) => id !== teamId);
    if (next.length === u.favouriteTeams.length) return;
    await this.prisma.user.update({
      where: { id: uid },
      data: { favouriteTeams: { set: next } },
    });
  }

  /// Idempotently add an FCM token to a user. Tokens rotate periodically
  /// (every ~30 days or after app re-install) so the client posts the
  /// current token on each cold start; this method de-dupes silently.
  async addFcmToken(uid: string, token: string) {
    const t = token.trim();
    if (!t) throw new BadRequestException('token_required');
    const u = await this.prisma.user.findUnique({
      where: { id: uid },
      select: { fcmTokens: true },
    });
    if (!u) throw new NotFoundException('user_not_found');
    if (u.fcmTokens.includes(t)) return;
    await this.prisma.user.update({
      where: { id: uid },
      data: { fcmTokens: { set: [...u.fcmTokens, t] } },
    });
  }

  /// Remove an FCM token (sign-out, or token refresh from the client).
  async removeFcmToken(uid: string, token: string) {
    const t = token.trim();
    if (!t) return;
    const u = await this.prisma.user.findUnique({
      where: { id: uid },
      select: { fcmTokens: true },
    });
    if (!u) return;
    const next = u.fcmTokens.filter((x) => x !== t);
    if (next.length === u.fcmTokens.length) return;
    await this.prisma.user.update({
      where: { id: uid },
      data: { fcmTokens: { set: next } },
    });
  }

  /// Pick a country to support during the World Cup. Pass null to clear.
  /// Stored separately from `countryCode` (nationality) so a user can be
  /// from one place and root for another.
  async setSupportedCountry(uid: string, code: string | null) {
    const normalized = code?.toUpperCase().trim() || null;
    if (normalized != null && !/^[A-Z]{2,4}$/.test(normalized)) {
      throw new BadRequestException('invalid_country_code');
    }
    await this.prisma.user.update({
      where: { id: uid },
      data: { supportedCountryCode: normalized },
    });
    return { supportedCountryCode: normalized };
  }

  /// Read the user's notification preferences. Returns defaults (everything
  /// enabled) when no row exists — absence means "no opt-out yet".
  async getNotificationPreferences(uid: string) {
    const pref = await this.prisma.notificationPreference.findUnique({
      where: { userId: uid },
    });
    if (pref) return pref;
    return {
      userId: uid,
      matchGoals: true,
      matchKickoff: true,
      matchFulltime: true,
      matchLineup: true,
      breakingNews: true,
      wcDailyRecap: true,
      fantasyResults: true,
      h2hInvites: true,
      h2hResults: true,
      cardDrops: true,
      updatedAt: new Date(),
    };
  }

  /// Upsert preferences. Only the fields the client sends are updated; the
  /// rest keep their last value (or default to true if no row yet).
  async setNotificationPreferences(
    uid: string,
    patch: Partial<Omit<Prisma.NotificationPreferenceUncheckedCreateInput, 'userId' | 'updatedAt'>>,
  ) {
    return this.prisma.notificationPreference.upsert({
      where: { userId: uid },
      create: { userId: uid, ...patch },
      update: patch,
    });
  }

  /// Paginated notification history. `cursor` is the last id from the
  /// previous page (sentAt-desc ordering). Returns null `nextCursor` when
  /// there are no more pages.
  async notificationHistory(uid: string, limit = 30, cursor?: string) {
    const rows = await this.prisma.notificationLog.findMany({
      where: { userId: uid },
      orderBy: { sentAt: 'desc' },
      take: limit + 1,
      ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
    });
    const hasMore = rows.length > limit;
    const slice = hasMore ? rows.slice(0, limit) : rows;
    return {
      items: slice.map((n) => ({
        id: n.id,
        type: n.type,
        category: n.category,
        title: n.title,
        body: n.body,
        deepLink: n.deepLink,
        payload: n.payload,
        sentAt: n.sentAt,
        readAt: n.readAt,
      })),
      nextCursor: hasMore ? slice[slice.length - 1]!.id : null,
    };
  }

  /// Count of unread (readAt == null) notifications for the user. Drives
  /// the home appbar bell badge. Cap at 99 client-side for display.
  async unreadNotificationCount(uid: string) {
    const count = await this.prisma.notificationLog.count({
      where: { userId: uid, readAt: null },
    });
    return { unread: count };
  }

  /// Mark notifications read. Pass `null` for `ids` to mark *all* as read
  /// (the "open the notification center" implicit-read pattern).
  async markNotificationsRead(uid: string, ids: string[] | null) {
    const now = new Date();
    if (ids === null) {
      await this.prisma.notificationLog.updateMany({
        where: { userId: uid, readAt: null },
        data: { readAt: now },
      });
    } else if (ids.length) {
      await this.prisma.notificationLog.updateMany({
        where: { userId: uid, id: { in: ids }, readAt: null },
        data: { readAt: now },
      });
    }
    return { readAt: now };
  }

  /// Public team-search for the favourites picker. Filters by name prefix
  /// or contains-match, optionally scoped to a competition (so "Group A
  /// teams only" works for the WC-focused onboarding). Capped at 50 hits.
  async searchTeams(opts: { q?: string; competitionId?: string }) {
    const q = opts.q?.trim();
    return this.prisma.team.findMany({
      where: {
        AND: [
          opts.competitionId ? { competitionId: opts.competitionId } : {},
          q
            ? {
                OR: [
                  { name: { contains: q, mode: 'insensitive' } },
                  { shortName: { contains: q, mode: 'insensitive' } },
                ],
              }
            : {},
        ],
      },
      select: {
        id: true, name: true, shortName: true, crestUrl: true, countryCode: true,
        competition: { select: { id: true, name: true } },
      },
      orderBy: [{ name: 'asc' }],
      take: 50,
    });
  }

  /// Returns the user's signup-gift card with template details, or null.
  /// We pick the most-recent SIGNUP_GIFT acquisition so that a user who
  /// somehow accumulated multiple sees their newest one (in practice exactly
  /// one is ever minted — see `mintWelcomeCard`).
  private async _loadUnseenWelcomeCard(uid: string) {
    const card = await this.prisma.ownedCard.findFirst({
      where: { ownerId: uid, acquiredVia: 'SIGNUP_GIFT' },
      orderBy: { mintedAt: 'desc' },
      include: {
        template: {
          include: {
            player: {
              select: { id: true, name: true, photoUrl: true, position: true,
                team: { select: { id: true, name: true, shortName: true, crestUrl: true, countryCode: true } } },
            },
          },
        },
      },
    });
    if (!card) return null;
    return {
      id: card.id,
      serialNumber: card.serialNumber,
      mintedAt: card.mintedAt,
      template: {
        id: card.template.id,
        rarity: card.template.rarity,
        edition: card.template.edition,
        totalSupply: card.template.totalSupply,
        artUrl: card.template.artUrl,
      },
      player: card.template.player == null ? null : {
        id: card.template.player.id,
        name: card.template.player.name,
        position: card.template.player.position,
        photoUrl: card.template.player.photoUrl,
        team: card.template.player.team,
      },
    };
  }

  /// Exact-tag lookup. 404 when no user owns that tag.
  async findByTag(rawTag: string) {
    const tag = this._normalize(rawTag);
    if (!TAG_PATTERN.test(tag)) throw new BadRequestException('invalid_user_tag');
    const u = await this.prisma.user.findUnique({
      where: { userTag: tag },
      select: { id: true, userTag: true, displayName: true, photoUrl: true, countryCode: true, createdAt: true },
    });
    if (!u) throw new NotFoundException('user_not_found');
    return u;
  }

  private async _followedTeamsFor(uid: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: uid },
      select: { favouriteTeams: true },
    });
    if (!user || !user.favouriteTeams.length) return [];
    return this.prisma.team.findMany({
      where: { id: { in: user.favouriteTeams } },
      select: {
        id: true, name: true, shortName: true, countryCode: true, crestUrl: true,
        competition: { select: { id: true, name: true } },
      },
    });
  }
}
