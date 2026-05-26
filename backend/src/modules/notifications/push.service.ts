import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../common/prisma.service';
import { FirebaseAdminService } from '../auth/firebase-admin.service';

/// Categories the user can opt out of. Maps 1:1 to columns on
/// NotificationPreference — keep these in sync when adding new categories.
export type NotificationCategory =
  | 'matchGoals'
  | 'matchKickoff'
  | 'matchFulltime'
  | 'matchLineup'
  | 'breakingNews'
  | 'wcDailyRecap'
  | 'fantasyResults'
  | 'h2hInvites'
  | 'h2hResults'
  | 'cardDrops';

interface PushArgs {
  userId: string;
  category: NotificationCategory;
  title: string;
  body: string;
  data?: Record<string, string>;
}

/// Single push entry-point for the whole app.
///
/// Responsibilities:
///   1. Skip when the user has opted out of `category`.
///   2. Send to every FCM token the user has registered.
///   3. Clean up dead tokens FCM reports as invalid — so over time the
///      user's `fcmTokens` array stays accurate without an out-of-band cron.
///
/// All failures are swallowed and logged at warn — push must never block
/// the state-change that triggered it (lineup save, gameweek score, etc).
@Injectable()
export class PushService {
  private readonly log = new Logger(PushService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly fcm: FirebaseAdminService,
  ) {}

  async pushToUser(args: PushArgs): Promise<void> {
    try {
      const user = await this.prisma.user.findUnique({
        where: { id: args.userId },
        select: {
          fcmTokens: true,
          notificationPreferences: { select: { [args.category]: true } as any },
        },
      });
      if (!user) return;

      // Default-on: missing preference row counts as opted-in. Only a
      // `false` explicitly written by the user suppresses the push.
      const pref = (user.notificationPreferences as Record<string, boolean> | null);
      if (pref && pref[args.category] === false) return;

      // Always log even when the user has no FCM tokens — the in-app
      // notification center should show what they would've received so
      // they can read it later (e.g. they signed in on a new device).
      await this.logToHistory(args);

      if (!user.fcmTokens.length) return;

      const res = await this.fcm.sendToTokens(
        user.fcmTokens,
        { title: args.title, body: args.body },
        // Always include category — client uses it to pick the Android
        // notification channel (mojo.match vs mojo.fantasy etc.).
        { category: args.category, ...(args.data ?? {}) },
      );
      if (res.invalidTokens.length) {
        await this.scrubTokens(args.userId, res.invalidTokens);
      }
    } catch (err) {
      this.log.warn(`push to ${args.userId} failed: ${(err as Error).message}`);
    }
  }

  /// Append the push to the user's notification history so the in-app
  /// notification center can render it. Never throws — log failure must
  /// not abort the push itself.
  private async logToHistory(args: PushArgs): Promise<void> {
    try {
      await this.prisma.notificationLog.create({
        data: {
          userId: args.userId,
          type: args.data?.type ?? args.category,
          category: args.category,
          title: args.title,
          body: args.body,
          deepLink: args.data?.deepLink ?? null,
          payload: (args.data ?? {}) as object,
        },
      });
    } catch (err) {
      this.log.warn(`notification log insert failed for ${args.userId}: ${(err as Error).message}`);
    }
  }

  /// Fan-out to many users for a single message — used by daily digests
  /// and breaking-news broadcasts. Chunks at 500 tokens per call to stay
  /// under FCM's multicast limit.
  async pushToUsers(
    userIds: string[],
    category: NotificationCategory,
    notification: { title: string; body: string },
    data?: Record<string, string>,
  ): Promise<void> {
    if (!userIds.length) return;
    try {
      // Pull tokens for users who haven't opted out of this category.
      const rows = await this.prisma.user.findMany({
        where: {
          id: { in: userIds },
          fcmTokens: { isEmpty: false },
          OR: [
            // No preference row → all-on defaults apply.
            { notificationPreferences: null },
            // Or the specific category is enabled.
            { notificationPreferences: { [category]: true } } as any,
          ],
        },
        select: { id: true, fcmTokens: true },
      });
      const tokens = rows.flatMap((r) => r.fcmTokens.map((t) => ({ uid: r.id, token: t })));
      if (!tokens.length) return;

      const chunkSize = 500;
      for (let i = 0; i < tokens.length; i += chunkSize) {
        const slice = tokens.slice(i, i + chunkSize);
        const res = await this.fcm.sendToTokens(
          slice.map((t) => t.token),
          notification,
          { category, ...(data ?? {}) },
        );
        if (res.invalidTokens.length) {
          // Map each invalid token back to its owner so we scrub the
          // correct row — different owners may share a stale token in
          // theory but the unique nature of FCM registration tokens
          // makes 1:1 fine in practice.
          const byOwner = new Map<string, string[]>();
          for (const tok of res.invalidTokens) {
            const owner = slice.find((t) => t.token === tok)?.uid;
            if (!owner) continue;
            byOwner.set(owner, [...(byOwner.get(owner) ?? []), tok]);
          }
          await Promise.all(
            [...byOwner.entries()].map(([uid, dead]) => this.scrubTokens(uid, dead)),
          );
        }
      }
    } catch (err) {
      this.log.warn(`broadcast push failed: ${(err as Error).message}`);
    }
  }

  /// Topic fan-out for sign-up-style subscriptions (country, WC digest).
  /// No preference filtering — opt-in is the topic subscription itself.
  async pushToTopic(
    topic: string,
    notification: { title: string; body: string },
    data?: Record<string, string>,
  ): Promise<void> {
    try {
      await this.fcm.sendToTopic(topic, notification, data);
    } catch (err) {
      this.log.warn(`topic push to ${topic} failed: ${(err as Error).message}`);
    }
  }

  /// Remove dead tokens from a user's row. Safe to call with tokens that
  /// aren't actually on the user — Prisma just no-ops.
  private async scrubTokens(userId: string, dead: string[]): Promise<void> {
    try {
      const u = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { fcmTokens: true },
      });
      if (!u) return;
      const next = u.fcmTokens.filter((t) => !dead.includes(t));
      if (next.length === u.fcmTokens.length) return;
      await this.prisma.user.update({
        where: { id: userId },
        data: { fcmTokens: { set: next } },
      });
      this.log.log(`scrubbed ${dead.length} dead FCM token(s) from ${userId}`);
    } catch (err) {
      this.log.warn(`token scrub failed for ${userId}: ${(err as Error).message}`);
    }
  }
}
