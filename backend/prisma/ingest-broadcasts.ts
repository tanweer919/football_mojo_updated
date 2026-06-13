/**
 * Ingest "where to watch" broadcast links from the scraper's
 * `broadcasts_by_fixture.json` straight into the DB. Mirrors
 * BroadcastsService.ingest(): replaces only SCRAPER-sourced links per match,
 * so admin-curated ADMIN links are never touched. Idempotent — safe to re-run.
 *
 * Self-contained (PrismaClient only) because the prod runtime image ships
 * dist/ + prisma/ but not src/.
 *
 * Input JSON shape (from `scraper.py --fixtures-api …`):
 *   { "<matchId>": [ { "country":"IN","countryName":"India",
 *       "broadcasters":[ {"name":"ZEE5","url":"https://…","logo":null} ] } ] }
 *
 * Run (easiest — from your dev box, pointed at prod DB; same as dokploy-seed.sh):
 *   DATABASE_URL=postgresql://USER:PASS@PROD-HOST:5432/DB \
 *     npx tsx prisma/ingest-broadcasts.ts ../tools/broadcast_scraper/broadcasts_by_fixture.json
 *
 * Or via npm:  npm run seed:broadcasts -- <path-to-json>
 */
import { PrismaClient } from '@prisma/client';
import { readFileSync } from 'node:fs';
import 'dotenv/config';

const prisma = new PrismaClient();

interface Broadcaster { name: string; url?: string | null; logo?: string | null }
interface CountryBroadcast { country?: string; countryName?: string; broadcasters?: Broadcaster[] }
type Payload = Record<string, CountryBroadcast[]>;

async function main() {
  const path = process.argv[2] ?? 'broadcasts_by_fixture.json';
  console.log(`[ingest-broadcasts] reading ${path}`);
  const data = JSON.parse(readFileSync(path, 'utf-8')) as Payload;

  const matchIds = Object.keys(data);
  console.log(`[ingest-broadcasts] ${matchIds.length} fixtures in file`);

  let matched = 0;
  let missing = 0;
  let inserted = 0;

  for (const matchId of matchIds) {
    const exists = await prisma.match.count({ where: { id: matchId } });
    if (!exists) {
      missing++;
      continue;
    }
    matched++;

    const groups = data[matchId] ?? [];
    const rows = groups.flatMap((g, gi) =>
      (g.broadcasters ?? []).map((b, bi) => ({
        matchId,
        source: 'SCRAPER' as const,
        name: b.name,
        url: b.url ?? null,
        countryCode: (g.country || '').toUpperCase() || null,
        countryName: g.countryName ?? null,
        logoUrl: b.logo ?? null,
        position: gi * 100 + bi,
      })),
    );
    inserted += rows.length;

    // Replace this match's SCRAPER links wholesale; leave ADMIN links intact.
    await prisma.$transaction([
      prisma.watchLink.deleteMany({ where: { matchId, source: 'SCRAPER' } }),
      ...(rows.length ? [prisma.watchLink.createMany({ data: rows })] : []),
    ]);
  }

  console.log('[ingest-broadcasts] done.');
  console.log(`  matched fixtures: ${matched}`);
  console.log(`  inserted links:   ${inserted}`);
  console.log(`  skipped (no match in DB): ${missing}`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
