#!/usr/bin/env npx tsx
/**
 * One-time photo refresh — runs locally to avoid server IP ban.
 *
 * Usage:
 *   cd backend
 *   npm run refresh:photos:remote
 *
 *   # or with custom API / premium key:
 *   API_BASE=https://api.footballmojo.in/api THESPORTSDB_KEY=xxx npm run refresh:photos:remote
 *   
 *   # dry run (search only, don't push):
 *   npm run refresh:photos:remote -- --dry-run
 */

import axios, { AxiosError } from 'axios';

const API_BASE     = (process.env.API_BASE ?? 'https://api.footballmojo.in/api').replace(/\/$/, '');
const SPORTSDB_KEY = process.env.THESPORTSDB_KEY ?? '123';
const SPORTSDB_URL = `https://www.thesportsdb.com/api/v1/json/${SPORTSDB_KEY}/searchplayers.php`;
const MAX_PER_MIN  = Number(process.env.MAX_PER_MIN ?? '25');
const BATCH_SIZE   = 50;
const DRY_RUN      = process.argv.includes('--dry-run');

const sleep = (ms: number) => new Promise(r => setTimeout(r, ms));

// ── Rate limiter ─────────────────────────────────────────────────────────

const stamps: number[] = [];
async function rateLimit() {
  for (;;) {
    const now = Date.now();
    while (stamps.length && now - stamps[0] >= 60_000) stamps.shift();
    if (stamps.length < MAX_PER_MIN) { stamps.push(now); return; }
    await sleep(60_000 - (now - stamps[0]) + 100);
  }
}

// ── Name utils (from refresh-player-photos.ts) ──────────────────────────

const PARTICLES = new Set(['van','von','de','da','di','del','der','den','dos','du','la','le','el','al','bin','ibn','mc']);

function parseName(raw: string) {
  const tokens = raw.trim().split(/\s+/);
  if (!tokens.length) return null;
  let si = tokens.length - 1;
  while (si > 0 && PARTICLES.has(tokens[si - 1].toLowerCase())) si--;
  const surname = tokens.slice(si).join(' ');
  let firstInitial: string | null = null;
  for (const t of tokens.slice(0, si)) {
    const l = t.replace(/[^A-Za-zÀ-ÿ]/g, '');
    if (l.length) { firstInitial = l[0].toUpperCase(); break; }
  }
  return { firstInitial, surname, full: raw.trim() };
}

function norm(s: string | null | undefined): string {
  return (s ?? '').normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
}

// ── TheSportsDB search ──────────────────────────────────────────────────

interface Hit { strPlayer: string; strTeam: string | null; strSport: string | null; strNationality: string | null; strCutout: string | null; strThumb: string | null; }

async function search(q: string): Promise<Hit[]> {
  for (let i = 0; i <= 3; i++) {
    if (i > 0) await sleep(i === 1 ? 2000 : 65_000);
    await rateLimit();
    try {
      const r = await axios.get(SPORTSDB_URL, { params: { p: q }, timeout: 20_000 });
      return ((r.data?.player ?? []) as Hit[]).filter(h => (h.strSport ?? '').toLowerCase() === 'soccer');
    } catch (e) {
      const s = (e as AxiosError).response?.status;
      if (s === 404) return [];
      if (s && s !== 429 && s < 500) throw e;
    }
  }
  return [];
}

function bestMatch(hits: Hit[], name: ReturnType<typeof parseName>, team: string | null, nat: string | null): Hit | null {
  if (!name || !hits.length) return null;
  const tgt = norm(name.surname);
  const ok = hits.filter(h => {
    const cn = norm(h.strPlayer);
    if (!cn.includes(tgt) && !tgt.includes(cn.split(' ').pop()!)) return false;
    if (name.firstInitial) {
      const ci = h.strPlayer.trim()[0]?.toUpperCase();
      if (ci !== name.firstInitial) return false;
    }
    return true;
  });
  if (!ok.length) return null;
  if (ok.length === 1) return ok[0];
  return ok.sort((a, b) => {
    let sa = 0, sb = 0;
    if (norm(a.strTeam) === norm(team)) sa += 8;
    if (norm(b.strTeam) === norm(team)) sb += 8;
    if (norm(a.strNationality) === norm(nat)) sa += 4;
    if (norm(b.strNationality) === norm(nat)) sb += 4;
    if (a.strCutout) sa += 2;
    if (b.strCutout) sb += 2;
    return sb - sa;
  })[0];
}

// ── Main ─────────────────────────────────────────────────────────────────

async function main() {
  console.log(`\n🖼️  Photo refresh (local → ${API_BASE})`);
  console.log(`   SportsDB key: ${SPORTSDB_KEY === '123' ? 'free-demo' : 'premium'}  rate: ${MAX_PER_MIN}/min`);
  console.log(`   Mode: ${DRY_RUN ? 'DRY RUN' : 'LIVE'}\n`);

  let page = 1, totalPages = 1, matched = 0, noMatch = 0, errors = 0, pushed = 0;
  const batch: { playerId: string; photoUrl: string }[] = [];

  while (page <= totalPages) {
    const { data } = await axios.get(`${API_BASE}/v1/internal/photos/pending`, {
      params: { page, pageSize: 100 },
    });
    totalPages = Math.ceil(data.total / data.pageSize);
    console.log(`📥 Page ${page}/${totalPages} — ${data.rows.length} players (${data.total} total)\n`);

    for (const p of data.rows as any[]) {
      const parsed = parseName(p.name);
      if (!parsed) { errors++; continue; }

      try {
        const q = parsed.firstInitial && !parsed.full.includes(' ') ? parsed.surname : parsed.full;
        let hits = await search(q);
        if (!hits.length && q !== parsed.surname) hits = await search(parsed.surname);

        const m = bestMatch(hits, parsed, p.team?.name, p.nationality);
        const url = m?.strCutout || m?.strThumb;
        if (!url || url === p.photoUrl) { noMatch++; continue; }

        matched++;
        console.log(`  ✓ ${p.name} → ${m!.strPlayer} ${m!.strCutout ? '✂' : '🖼'}`);
        batch.push({ playerId: p.id, photoUrl: url });

        if (batch.length >= BATCH_SIZE) {
          pushed += await flush(batch.splice(0));
        }
      } catch (e) {
        errors++;
        console.error(`  ✗ ${p.name}: ${e instanceof Error ? e.message : e}`);
      }
    }
    page++;
  }

  if (batch.length) pushed += await flush(batch.splice(0));

  console.log(`\n✅ Done — matched: ${matched}  pushed: ${pushed}  no-match: ${noMatch}  errors: ${errors}`);
}

async function flush(batch: { playerId: string; photoUrl: string }[]): Promise<number> {
  if (DRY_RUN) { console.log(`   📦 dry-run: ${batch.length} skipped`); return 0; }
  try {
    const { data } = await axios.patch(`${API_BASE}/v1/internal/photos/batch`, { updates: batch });
    console.log(`   📦 pushed ${data.updated}`);
    return data.updated;
  } catch (e) {
    console.error(`   ❌ push failed: ${axios.isAxiosError(e) ? e.response?.status : e}`);
    return 0;
  }
}

main().catch(e => { console.error(e); process.exit(1); });
