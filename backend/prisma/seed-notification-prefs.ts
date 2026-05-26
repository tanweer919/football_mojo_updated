/**
 * Materialise NotificationPreference rows for every user that lacks one.
 *
 * Idempotent — `upsert` with empty `update` means re-runs do nothing
 * once every user has a row. Safe to wire into the deploy pipeline.
 *
 * Why: PushService treats absent rows as "all defaults on", so the app
 * works without this script. But analytics queries and admin filters
 * are simpler when the table is fully populated. Run once after the
 * notification-prefs migration deploys.
 *
 * Usage:
 *   npm run seed:notification-prefs
 */

import { PrismaClient } from '@prisma/client';
import 'dotenv/config';

const prisma = new PrismaClient();

async function run() {
  // Stream in pages of 1k users so memory stays flat even on big DBs.
  // Workflow: read uid → upsert empty row → loop. ~1ms per user.
  const pageSize = 1000;
  let cursor: string | undefined;
  let created = 0;
  let processed = 0;

  for (;;) {
    const batch = await prisma.user.findMany({
      take: pageSize,
      ...(cursor ? { skip: 1, cursor: { id: cursor } } : {}),
      orderBy: { id: 'asc' },
      select: { id: true },
    });
    if (!batch.length) break;

    for (const u of batch) {
      const res = await prisma.notificationPreference.upsert({
        where: { userId: u.id },
        create: { userId: u.id },
        update: {},
      });
      // `upsert` doesn't tell us which branch ran, so we re-check by
      // looking at updatedAt — fresh row will be within the last few ms.
      if (Date.now() - res.updatedAt.getTime() < 5_000) created++;
      processed++;
    }

    cursor = batch[batch.length - 1]!.id;
    console.log(`  …processed ${processed} (+${created} new)`);
    if (batch.length < pageSize) break;
  }

  console.log(`Done. ${processed} users processed, ${created} new pref rows created.`);
}

run()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
