#!/usr/bin/env npx tsx
/**
 * Test notification script — sends every notification type to a user.
 *
 * Usage:
 *   EMAIL=tanweer.anwar919@gmail.com npx tsx scripts/test-notifications.ts
 *
 *   # or via npm:
 *   EMAIL=tanweer.anwar919@gmail.com npm run test:notifications
 */

import { PrismaClient } from '@prisma/client';
import * as admin from 'firebase-admin';
import 'dotenv/config';

const prisma = new PrismaClient();

// ─── Firebase Admin init ─────────────────────────────────────────────────

function initFirebase() {
  if (admin.apps.length) return;
  const b64 = process.env.FIREBASE_SERVICE_ACCOUNT_B64;
  if (!b64) {
    console.error('❌ FIREBASE_SERVICE_ACCOUNT_B64 env var is required');
    process.exit(1);
  }
  const json = JSON.parse(Buffer.from(b64.trim(), 'base64').toString('utf8'));
  admin.initializeApp({ credential: admin.credential.cert(json as admin.ServiceAccount) });
}

// ─── All notification types ──────────────────────────────────────────────

interface TestNotification {
  category: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

const NOTIFICATIONS: TestNotification[] = [
  // Match events
  {
    category: 'matchGoals',
    title: '⚽ ARG 1-0 BRA',
    body: "23' Goal — Lionel Messi",
    data: { type: 'GOAL', deepLink: 'footballmojo://matches/test-123' },
  },
  {
    category: 'matchKickoff',
    title: 'Kick-off · Argentina vs Brazil',
    body: 'Match started',
    data: { type: 'KICKOFF', deepLink: 'footballmojo://matches/test-123' },
  },
  {
    category: 'matchFulltime',
    title: 'Full-time · Argentina 2-1 Brazil',
    body: 'Final whistle',
    data: { type: 'FULLTIME', deepLink: 'footballmojo://matches/test-123' },
  },
  {
    category: 'matchLineup',
    title: '📋 Lineup confirmed — Argentina',
    body: 'Messi starts, Dybala on the bench',
    data: { type: 'LINEUP', deepLink: 'footballmojo://matches/test-123' },
  },

  // News
  {
    category: 'breakingNews',
    title: '🔴 Breaking: Messi confirms retirement after WC 2026',
    body: 'The Argentine legend announced his final tournament appearance.',
    data: { type: 'breaking_news', deepLink: 'footballmojo://news' },
  },
  {
    category: 'wcDailyRecap',
    title: '🏆 WC 2026 Daily Recap — Day 5',
    body: '3 matches played. Argentina tops Group A. See all results.',
    data: { type: 'daily_recap', deepLink: 'footballmojo://news' },
  },

  // Fantasy
  {
    category: 'fantasyResults',
    title: 'GW1 results in',
    body: 'You finished #42 with 87.3 pts.',
    data: { type: 'fantasy_result', deepLink: 'footballmojo://fantasy' },
  },

  // H2H
  {
    category: 'h2hInvites',
    title: '⚔️ You have a new 1v1 challenge!',
    body: '@messi_fan challenged you for GW2. Tap to accept.',
    data: { type: 'h2h_invite', deepLink: 'footballmojo://h2h' },
  },
  {
    category: 'h2hResults',
    title: '🏆 1v1 Result: You won!',
    body: 'You beat @messi_fan 94.5 to 72.1 pts.',
    data: { type: 'h2h_result', deepLink: 'footballmojo://h2h' },
  },

  // Cards
  {
    category: 'cardDrops',
    title: '🃏 New stage edition — Round of 16',
    body: 'WC2026-R16 cards are now available in the store!',
    data: { type: 'card_drop', deepLink: 'footballmojo://cards/store' },
  },
];

// ─── Main ────────────────────────────────────────────────────────────────

async function main() {
  const email = process.env.EMAIL ?? 'tanweer.anwar919@gmail.com';
  console.log(`\n🔔 Notification test — sending all types to: ${email}\n`);

  initFirebase();

  // Find user
  const user = await prisma.user.findFirst({
    where: { email },
    select: { id: true, email: true, displayName: true, fcmTokens: true },
  });

  if (!user) {
    console.error(`❌ No user found with email: ${email}`);
    process.exit(1);
  }

  console.log(`  User:   ${user.displayName ?? user.email} (${user.id})`);
  console.log(`  Tokens: ${user.fcmTokens.length}`);

  if (!user.fcmTokens.length) {
    console.error(`\n❌ User has no FCM tokens registered.`);
    console.error(`   This means the app hasn't sent its push token to the server.`);
    console.error(`   Possible causes:`);
    console.error(`     1. User denied notification permission on the device`);
    console.error(`     2. FcmBootstrap.ensureRegistered() never ran (auth state issue)`);
    console.error(`     3. POST /v1/users/me/fcm-tokens failed silently`);
    console.error(`\n   To debug:`);
    console.error(`     - Check if the user has granted notification permission in the app`);
    console.error(`     - Check backend logs for "FCM token registered" messages`);
    console.error(`     - Run: SELECT "fcmTokens" FROM "User" WHERE email = '${email}';`);
    process.exit(1);
  }

  console.log(`\n  Sending ${NOTIFICATIONS.length} notifications (2s apart)…\n`);

  let sent = 0;
  let failed = 0;

  for (const n of NOTIFICATIONS) {
    try {
      const res = await admin.messaging().sendEachForMulticast({
        tokens: user.fcmTokens,
        notification: { title: n.title, body: n.body },
        data: { category: n.category, ...(n.data ?? {}) },
        // Android: use high priority so the notification arrives immediately
        android: { priority: 'high' },
        // iOS: set content-available for background delivery
        apns: { payload: { aps: { contentAvailable: true, sound: 'default' } } },
      });

      const ok = res.responses.filter(r => r.success).length;
      const fail = res.responses.filter(r => !r.success);

      if (ok > 0) {
        sent++;
        console.log(`  ✓ [${n.category}] ${n.title}`);
      }
      if (fail.length) {
        for (const f of fail) {
          console.error(`  ✗ [${n.category}] ${f.error?.code}: ${f.error?.message}`);
          // If token is invalid, note it
          if (
            f.error?.code === 'messaging/invalid-registration-token' ||
            f.error?.code === 'messaging/registration-token-not-registered'
          ) {
            console.error(`    → Token is dead/invalid. User needs to re-open the app.`);
          }
        }
        failed++;
      }

      // Also log to NotificationLog so it shows in the in-app notification center
      await prisma.notificationLog.create({
        data: {
          userId: user.id,
          type: n.data?.type ?? n.category,
          category: n.category,
          title: n.title,
          body: n.body,
          deepLink: n.data?.deepLink ?? null,
          payload: (n.data ?? {}) as object,
        },
      }).catch(() => {}); // best-effort

      // 2s between notifications so they arrive as distinct items
      await new Promise(r => setTimeout(r, 2000));
    } catch (e) {
      failed++;
      console.error(`  ✗ [${n.category}] ERROR: ${(e as Error).message}`);
    }
  }

  console.log(`\n✅ Done — sent: ${sent}  failed: ${failed}`);
  if (sent === 0 && failed > 0) {
    console.log(`\n⚠️  All notifications failed. The FCM tokens are likely expired.`);
    console.log(`   Open the app on the device, let it register, then retry.`);
  }
}

main()
  .catch(e => { console.error(e); process.exit(1); })
  .finally(() => prisma.$disconnect());
