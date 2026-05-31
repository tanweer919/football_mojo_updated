#!/usr/bin/env npx tsx
/**
 * One-time photo refresh — runs locally to avoid server IP ban.
 *
 * Usage:
 *   cd backend
 *   npm run refresh:photos:remote
 *
 *   # Premium TheSportsDB key (faster):
 *   THESPORTSDB_KEY=xxx MAX_PER_MIN=100 npm run refresh:photos:remote
 *
 *   # Custom API base:
 *   API_BASE=http://localhost:3000/api npm run refresh:photos:remote
 *
 *   # Re-fetch even players that already have TheSportsDB cutouts:
 *   npm run refresh:photos:remote -- --force
 *
 *   # Search only, don't push to server:
 *   npm run refresh:photos:remote -- --dry-run
 */

import axios, { AxiosError } from 'axios';

// ─── Config ──────────────────────────────────────────────────────────────

const API_BASE     = (process.env.API_BASE ?? 'https://api.footballmojo.in/api').replace(/\/$/, '');
const SPORTSDB_KEY = process.env.THESPORTSDB_KEY ?? '123';
const SPORTSDB_URL = `https://www.thesportsdb.com/api/v1/json/${SPORTSDB_KEY}/searchplayers.php`;
const MAX_PER_MIN  = Number(process.env.MAX_PER_MIN ?? '28');
const CONCURRENCY  = Number(process.env.CONCURRENCY ?? '3');
const BATCH_SIZE   = 50;
const DRY_RUN      = process.argv.includes('--dry-run');
const FORCE        = process.argv.includes('--force');

const sleep = (ms: number) => new Promise(r => setTimeout(r, ms));

// ─── Rate limiter (sliding window) ──────────────────────────────────────

const stamps: number[] = [];
async function rateLimit() {
  for (;;) {
    const now = Date.now();
    while (stamps.length && now - stamps[0] >= 60_000) stamps.shift();
    if (stamps.length < MAX_PER_MIN) { stamps.push(now); return; }
    const wait = 60_000 - (now - stamps[0]) + 100;
    process.stdout.write(`  ⏳ rate-limit — waiting ${(wait / 1000).toFixed(0)}s…\r`);
    await sleep(wait);
  }
}

// ─── Name parsing (from refresh-player-photos.ts) ────────────────────────

const PARTICLES = new Set([
  'van','von','de','da','di','del','der','den','dos','du',
  'la','le','el','al','bin','ibn','mc',
]);

interface ParsedName { firstInitial: string | null; surname: string; full: string; }

function parseName(raw: string): ParsedName | null {
  const cleaned = raw.replace(/\s+/g, ' ').trim();
  if (!cleaned) return null;
  const tokens = cleaned.split(' ');
  let si = tokens.length - 1;
  while (si > 0 && PARTICLES.has(tokens[si - 1].toLowerCase())) si--;
  const surname = tokens.slice(si).join(' ');
  const firstTokens = tokens.slice(0, si);
  let firstInitial: string | null = null;
  for (const t of firstTokens) {
    const letters = t.replace(/[^A-Za-zÀ-ÿ]/g, '');
    if (letters.length > 0) { firstInitial = letters[0].toUpperCase(); break; }
  }
  return { firstInitial, surname, full: cleaned };
}

function norm(s: string | null | undefined): string {
  return (s ?? '').normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
}

// ─── TheSportsDB ────────────────────────────────────────────────────────

interface Hit {
  strPlayer: string;
  strTeam: string | null;
  strSport: string | null;
  strNationality: string | null;
  strCutout: string | null;
  strThumb: string | null;
}

async function search(query: string): Promise<Hit[]> {
  for (let attempt = 0; attempt <= 3; attempt++) {
    if (attempt > 0) {
      const backoff = attempt === 1 ? 1_500 : 30_000;
      console.warn(`  retry ${attempt}/3 for "${query}" after ${(backoff / 1000).toFixed(0)}s`);
      await sleep(backoff);
    }
    await rateLimit();
    try {
      const res = await axios.get(SPORTSDB_URL, { params: { p: query }, timeout: 8_000 });
      return ((res.data?.player ?? []) as Hit[]).filter(h => (h.strSport ?? '').toLowerCase() === 'soccer');
    } catch (e) {
      const status = (e as AxiosError).response?.status;
      if (status === 404) return [];
      if (status && status !== 429 && status < 500) throw e;
      if (status === 429) console.warn(`  429 rate-limited by TheSportsDB`);
    }
  }
  return [];
}

// ─── Matching (from refresh-player-photos.ts) ───────────────────────────

function chooseMatch(
  hits: Hit[],
  parsed: ParsedName,
  teamName: string | null,
  nationality: string | null,
): Hit | null {
  if (!hits.length) return null;
  const targetSurname = norm(parsed.surname);

  const survivors = hits.filter(h => {
    const cn = norm(h.strPlayer);
    if (!cn) return false;
    // surname must appear somewhere in the candidate
    if (!cn.includes(targetSurname)) {
      const lastWord = cn.split(' ').pop()!;
      if (!targetSurname.includes(lastWord)) return false;
    }
    // first initial must match
    if (parsed.firstInitial) {
      const ci = h.strPlayer.trim()[0]?.toUpperCase();
      if (ci !== parsed.firstInitial) return false;
    }
    return true;
  });

  if (!survivors.length) return null;
  if (survivors.length === 1) return survivors[0];

  // score and rank
  return survivors
    .map(c => {
      let score = 0;
      if (norm(c.strPlayer).endsWith(targetSurname)) score += 6;
      if (teamName && norm(c.strTeam) === norm(teamName)) score += 8;
      if (nationality && norm(c.strNationality) === norm(nationality)) score += 4;
      if (c.strCutout) score += 2;
      return { c, score };
    })
    .sort((a, b) => b.score - a.score)[0].c;
}

// ─── Main ────────────────────────────────────────────────────────────────

interface Player {
  id: string;
  name: string;
  photoUrl: string | null;
  nationality: string | null;
  team: { name: string; shortName: string } | null;
}

interface Stats {
  total: number;
  scanned: number;
  matched: number;
  updated: number;
  pushed: number;
  skipped: number;
  noMatch: number;
  rejected: number;
  errors: number;
}

async function processPlayer(
  p: Player, stats: Stats, batch: { playerId: string; photoUrl: string }[],
): Promise<void> {
  stats.scanned++;
  const prefix = `[${stats.scanned}/${stats.total}]`;

  if (!FORCE && p.photoUrl && p.photoUrl.includes('thesportsdb.com')) {
    stats.skipped++;
    return;
  }

  const parsed = parseName(p.name);
  if (!parsed) {
    stats.errors++;
    console.error(`${prefix} unparseable name: '${p.name}'`);
    return;
  }

  try {
    const primary = parsed.firstInitial && !parsed.full.includes(' ')
      ? parsed.surname : parsed.full;
    let hits = await search(primary);
    if (hits.length === 0 && primary !== parsed.surname) {
      hits = await search(parsed.surname);
    }

    const match = chooseMatch(hits, parsed, p.team?.name ?? null, p.nationality);
    if (!match) {
      if (hits.length > 0) {
        stats.rejected++;
        console.log(`${prefix} rejected (no candidate passed filters): ${p.name} — ${hits.length} hit(s)`);
      } else {
        stats.noMatch++;
        console.log(`${prefix} no match: ${p.name} (${p.team?.shortName ?? '—'})`);
      }
      return;
    }

    const newUrl = match.strCutout || match.strThumb;
    if (!newUrl) {
      stats.noMatch++;
      console.log(`${prefix} hit but no image: ${p.name} → ${match.strPlayer}`);
      return;
    }
    if (newUrl === p.photoUrl) {
      stats.skipped++;
      return;
    }

    stats.matched++;
    console.log(`${prefix} ${p.name} → ${match.strPlayer} (${match.strTeam ?? '—'})  ${match.strCutout ? 'cutout' : 'thumb'}`);
    batch.push({ playerId: p.id, photoUrl: newUrl });
  } catch (e) {
    stats.errors++;
    console.error(`${prefix} ERROR ${p.name}: ${e instanceof Error ? e.message : String(e)}`);
  }
}

async function main() {
  console.log(`[refresh-photos-remote] key=${SPORTSDB_KEY === '123' ? '<free-demo>' : '<premium>'} rate=${MAX_PER_MIN}/60s concurrency=${CONCURRENCY} force=${FORCE} dryRun=${DRY_RUN}`);
  console.log(`[refresh-photos-remote] api=${API_BASE}`);
  console.log(`[refresh-photos-remote] querying players…`);

  // Fetch all players across pages
  const allPlayers: Player[] = [];
  let page = 1;
  let totalPages = 1;
  while (page <= totalPages) {
    const { data } = await axios.get(`${API_BASE}/v1/internal/photos/pending`, {
      params: { page, pageSize: 500 },
      timeout: 10_000,
    });
    allPlayers.push(...data.rows);
    totalPages = Math.ceil(data.total / data.pageSize);
    page++;
  }

  const stats: Stats = {
    total: allPlayers.length, scanned: 0, matched: 0, updated: 0,
    pushed: 0, skipped: 0, noMatch: 0, rejected: 0, errors: 0,
  };
  const startTime = Date.now();
  console.log(`[refresh-photos-remote] total players: ${stats.total}\n`);

  const batch: { playerId: string; photoUrl: string }[] = [];

  // Process players with concurrency — rate limiter serialises the
  // actual HTTP calls anyway, but overlapping name-parse + match logic
  // and allowing multiple search() calls to queue keeps throughput high.
  for (let i = 0; i < allPlayers.length; i += CONCURRENCY) {
    const chunk = allPlayers.slice(i, i + CONCURRENCY);
    await Promise.all(chunk.map(p => processPlayer(p, stats, batch)));

    // Push batch when full
    if (batch.length >= BATCH_SIZE) {
      const n = await pushBatch(batch.splice(0));
      stats.pushed += n;
      stats.updated += n;
    }

    // ETA
    if (stats.scanned % 50 === 0 && stats.scanned > 0) {
      const elapsed = (Date.now() - startTime) / 1000;
      const rate = stats.scanned / elapsed;
      const remaining = (stats.total - stats.scanned) / rate;
      console.log(`  ⏱  ${stats.scanned}/${stats.total} — ${rate.toFixed(1)}/s — ETA ${Math.ceil(remaining / 60)}min`);
    }
  }

  // Flush remaining
  if (batch.length > 0) {
    const n = await pushBatch(batch.splice(0));
    stats.pushed += n;
    stats.updated += n;
  }

  console.log(`\n[refresh-photos-remote] done`);
  console.log(`  scanned:   ${stats.scanned}`);
  console.log(`  matched:   ${stats.matched}`);
  console.log(`  updated:   ${stats.updated}${DRY_RUN ? ' (dry-run, no writes)' : ''}`);
  console.log(`  skipped:   ${stats.skipped}`);
  console.log(`  no-match:  ${stats.noMatch}`);
  console.log(`  rejected:  ${stats.rejected}`);
  console.log(`  errors:    ${stats.errors}`);
}

async function pushBatch(batch: { playerId: string; photoUrl: string }[]): Promise<number> {
  if (!batch.length) return 0;
  if (DRY_RUN) {
    console.log(`\n  📦 [dry-run] would push ${batch.length} updates\n`);
    return 0;
  }
  try {
    console.log(`\n  📦 pushing ${batch.length} updates…`);
    const { data } = await axios.patch(`${API_BASE}/v1/internal/photos/batch`, { updates: batch }, { timeout: 10_000 });
    console.log(`  ✓ ${data.updated} written to DB\n`);
    return data.updated;
  } catch (e) {
    const msg = axios.isAxiosError(e)
      ? `${e.response?.status}: ${JSON.stringify(e.response?.data)}`
      : String(e);
    console.error(`  ❌ batch push failed: ${msg}\n`);
    return 0;
  }
}

main().catch(e => { console.error(e); process.exit(1); });
