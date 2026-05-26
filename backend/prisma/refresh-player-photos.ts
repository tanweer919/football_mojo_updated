/**
 * Refresh `Player.photoUrl` from TheSportsDB cut-out images.
 *
 * Motivation:
 *   api-football headshots are ~500×500 with a hard white background. They
 *   render as a bright rectangle on the dark NFT-style cards we draw
 *   client-side. TheSportsDB ships PNG cut-outs (transparent background,
 *   higher resolution) under `strCutout` — those drop straight onto the
 *   card art layer without any post-processing.
 *
 * Hard constraints learned from a real run:
 *   - api-football stores names as `A. Abada`, `K. Mitoma`, `B. Iglesias`.
 *     TheSportsDB's `searchplayers.php` does a substring match, so an
 *     unguarded query for `A. Abada` returns *Liel* Abada (false positive).
 *     We must reject candidates whose own first initial / first letter
 *     does not match the DB player's.
 *   - The free demo key is rate-limited to **30 req / 60 s rolling window**.
 *     A plain sleep-between-requests bursts past this (1500ms delay → 40/min).
 *     We need a real sliding-window limiter that *waits until* the oldest
 *     request drops out of the window.
 *
 * Strategy:
 *   1. For each Player, derive a `(firstInitial, surname)` pair from their
 *      stored name. "A. Abada" → ("A", "Abada"). "Virgil van Dijk" →
 *      ("V", "van Dijk"). "Casemiro" → (null, "Casemiro").
 *   2. Try searching the full name first; if zero hits, retry by surname.
 *   3. Filter out candidates whose first name doesn't start with the DB
 *      first initial. Filter out candidates whose surname doesn't contain
 *      our surname (accent / case normalized).
 *   4. Among survivors, score: same-team > same-nationality > cutout-present
 *      > exact-name. Pick the top score.
 *   5. Write `Player.photoUrl` and cascade `CardTemplate.artUrl` for that
 *      player (seed-wc-cards snapshots the photo URL into the template at
 *      mint time, so they have to be updated together).
 *
 * Idempotent + resumable:
 *   Players whose `photoUrl` already points at `thesportsdb.com` are skipped
 *   by default. Pass `--force` to re-fetch.
 *
 * Run:
 *   docker compose exec api npm run refresh:photos
 *   # premium key, faster:
 *   docker compose exec -e THESPORTSDB_KEY=xxxx \
 *     -e THESPORTSDB_MAX_PER_MIN=100 api npm run refresh:photos -- --force
 */

import { PrismaClient } from '@prisma/client';
import axios, { AxiosError } from 'axios';
import 'dotenv/config';

const prisma = new PrismaClient();

const API_KEY = process.env.THESPORTSDB_KEY ?? '123';
const BASE_URL = `https://www.thesportsdb.com/api/v1/json/${API_KEY}`;
// Free tier docs: 30/min. We default to 28 to leave headroom for clock drift
// and the occasional retry. Premium tiers can override via env.
const MAX_PER_MIN = Number(process.env.THESPORTSDB_MAX_PER_MIN ?? '28');
const MAX_RETRIES = 4;
// Cool-down when a 429 slips through anyway. Free-tier's window is 60s,
// so 65s guarantees the offending request is out of it.
const RATE_LIMIT_COOLDOWN_MS = Number(process.env.THESPORTSDB_RATE_LIMIT_COOLDOWN_MS ?? '65000');

const FORCE = process.argv.includes('--force');
const DRY_RUN = process.argv.includes('--dry-run');
const ONLY_MISSING = process.argv.includes('--only-missing');

interface SportsDbPlayer {
  idPlayer: string;
  strPlayer: string;
  strTeam: string | null;
  strSport: string | null;
  strNationality: string | null;
  strThumb: string | null;
  strCutout: string | null;
  relevance?: string;
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

// ─── Rate limiter ────────────────────────────────────────────────────────

/// Strict sliding-window limiter. `acquire()` blocks until *fewer than*
/// `maxPerWindow` calls have completed inside the last `windowMs` ms — at
/// which point it records its own timestamp and returns.
///
/// Why this and not a sleep: a 1500 ms sleep makes ~40 calls/min, which
/// looks fine on paper but bursts past the API's rolling cap of 30/min
/// after exactly 30 calls (we hit "31" before the first call has aged out).
/// A sliding window guarantees the invariant on every call, not just on
/// average.
class SlidingWindowLimiter {
  private readonly stamps: number[] = [];
  constructor(private readonly maxPerWindow: number, private readonly windowMs: number) {}

  async acquire(): Promise<void> {
    // Loop because once we sleep, more callers may have queued ahead of us
    // — recheck after waking.
    for (;;) {
      const now = Date.now();
      // Drop timestamps that have aged out of the window.
      while (this.stamps.length && now - this.stamps[0] >= this.windowMs) {
        this.stamps.shift();
      }
      if (this.stamps.length < this.maxPerWindow) {
        this.stamps.push(now);
        return;
      }
      // Sleep just long enough for the oldest stamp to drop out, plus a
      // 50 ms margin against clock-drift / float-rounding off-by-ones.
      const wait = this.windowMs - (now - this.stamps[0]) + 50;
      await sleep(wait);
    }
  }
}

const limiter = new SlidingWindowLimiter(MAX_PER_MIN, 60_000);

// ─── Name parsing ────────────────────────────────────────────────────────

interface ParsedName {
  /// Uppercase first-letter of the player's given name, when we know it.
  /// Comes from either "A. Abada" → "A" or "Virgil van Dijk" → "V". null
  /// when the row only has a single token ("Casemiro", "Vinícius Júnior"
  /// where Vinícius isn't really a separable first name).
  firstInitial: string | null;
  /// Surname, accent/case preserved for display, with leading lowercase
  /// particles kept ("van Dijk", "de Bruyne", "dos Santos").
  surname: string;
  /// Tokens you'd pass to a name search — joined with spaces.
  full: string;
}

const PARTICLES = new Set(['van', 'von', 'de', 'da', 'di', 'del', 'der', 'den', 'dos', 'du', 'la', 'le', 'el', 'al', 'bin', 'ibn', 'mc']);

function parseName(raw: string): ParsedName | null {
  const cleaned = raw.replace(/\s+/g, ' ').trim();
  if (!cleaned) return null;

  const tokens = cleaned.split(' ');
  // Pull surname: walk from the right, gluing in lowercase particles.
  let surnameStart = tokens.length - 1;
  while (
    surnameStart > 0 &&
    PARTICLES.has(tokens[surnameStart - 1].toLowerCase())
  ) {
    surnameStart--;
  }
  const surname = tokens.slice(surnameStart).join(' ');

  // First-name region (everything before the surname). Could be empty
  // (single-token names) or contain initials like "A.".
  const firstTokens = tokens.slice(0, surnameStart);
  let firstInitial: string | null = null;
  for (const t of firstTokens) {
    const letters = t.replace(/[^A-Za-zÀ-ÿ]/g, '');
    if (letters.length > 0) {
      firstInitial = letters[0].toUpperCase();
      break;
    }
  }

  return { firstInitial, surname, full: cleaned };
}

/// Strip accents, lowercase, collapse non-alphanum. "Aït-Nouri" → "ait nouri".
function normalize(s: string | null | undefined): string {
  if (!s) return '';
  return s
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

/// "Liel Abada" → "L"; "Bin Mohammed" → "B".
function candidateFirstInitial(strPlayer: string): string | null {
  const tokens = strPlayer.trim().split(/\s+/);
  for (const t of tokens) {
    const letters = t.replace(/[^A-Za-zÀ-ÿ]/g, '');
    if (letters.length > 0) return letters[0].toUpperCase();
  }
  return null;
}

// ─── API search with retries + rate-limiter ──────────────────────────────

async function search(query: string): Promise<SportsDbPlayer[]> {
  let lastErr: unknown;
  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    if (attempt > 0) {
      // 429s usually mean we're hammering — cool down for a full window
      // before retrying. Other 5xx errors get a shorter linear backoff.
      const isRateLimited = (lastErr as AxiosError | undefined)?.response?.status === 429;
      const backoff = isRateLimited
        ? RATE_LIMIT_COOLDOWN_MS
        : Math.min(15_000, 1_000 * 2 ** (attempt - 1));
      if (isRateLimited) {
        console.warn(`  hit 429, cooling down ${(backoff / 1000).toFixed(0)}s…`);
      }
      await sleep(backoff);
    }
    await limiter.acquire();
    try {
      const url = `${BASE_URL}/searchplayers.php`;
      const res = await axios.get(url, {
        // TheSportsDB accepts spaces or underscores; spaces avoid the
        // earlier "A._Abada" double-encoding quirk.
        params: { p: query.trim() },
        timeout: 20_000,
      });
      // `player` is `null` rather than `[]` when no hits — quirk of the API.
      const list = (res.data?.player as SportsDbPlayer[] | null) ?? [];
      return list.filter((p) => (p.strSport ?? '').toLowerCase() === 'soccer');
    } catch (e) {
      lastErr = e;
      const ax = e as AxiosError;
      const status = ax.response?.status;
      // 404 = no hit, treat as empty result.
      if (status === 404) return [];
      // Anything other than 429 / 5xx surfaces immediately.
      if (status && status !== 429 && status < 500) throw e;
    }
  }
  throw lastErr;
}

// ─── Candidate scoring ───────────────────────────────────────────────────

function chooseMatch(
  candidates: SportsDbPlayer[],
  dbName: ParsedName,
  dbTeam: string | null,
  dbNationality: string | null,
): SportsDbPlayer | null {
  if (candidates.length === 0) return null;

  const targetSurname = normalize(dbName.surname);
  const targetTeam = normalize(dbTeam);
  const targetNat = normalize(dbNationality);

  // Hard filters: candidate must (a) share our surname (accent-normalized
  // substring match in either direction handles "Ait Nouri" ↔ "Aït Nouri")
  // and (b) if we know the first initial, theirs has to match too.
  const survivors = candidates.filter((c) => {
    const cName = normalize(c.strPlayer);
    if (!cName) return false;
    // Surname containment in either direction. Pure equality is too strict
    // for compound surnames like "Ait Boudlal" vs "Aït-Boudlal".
    if (
      !cName.includes(targetSurname) &&
      !targetSurname.includes(cName.split(' ').slice(-1)[0])
    ) return false;
    if (dbName.firstInitial) {
      const cInit = candidateFirstInitial(c.strPlayer);
      if (cInit !== dbName.firstInitial) return false;
    }
    return true;
  });

  if (survivors.length === 0) return null;
  if (survivors.length === 1) return survivors[0];

  const scored = survivors.map((c) => {
    let score = 0;
    if (normalize(c.strPlayer).endsWith(targetSurname)) score += 6;
    if (targetTeam && normalize(c.strTeam) === targetTeam) score += 8;
    if (targetNat && normalize(c.strNationality) === targetNat) score += 4;
    if (c.strCutout) score += 2;
    return { c, score };
  });
  scored.sort((a, b) => b.score - a.score);
  return scored[0].c;
}

// ─── Main ────────────────────────────────────────────────────────────────

interface Stats {
  total: number;
  scanned: number;
  matched: number;
  updated: number;
  skipped: number;
  noMatch: number;
  rejected: number;
  errors: number;
}

async function main() {
  console.log(`[refresh-photos] key=${API_KEY === '123' ? '<free-demo>' : '<premium>'} rate=${MAX_PER_MIN}/60s force=${FORCE} dryRun=${DRY_RUN}`);
  console.log(`[refresh-photos] querying players…`);

  const players = await prisma.player.findMany({
    where: ONLY_MISSING ? { photoUrl: null } : undefined,
    select: {
      id: true,
      name: true,
      photoUrl: true,
      nationality: true,
      team: { select: { id: true, name: true, shortName: true } },
    },
    orderBy: { name: 'asc' },
  });

  const stats: Stats = {
    total: players.length, scanned: 0, matched: 0, updated: 0,
    skipped: 0, noMatch: 0, rejected: 0, errors: 0,
  };
  console.log(`[refresh-photos] total players: ${stats.total}`);

  for (const p of players) {
    stats.scanned++;
    const prefix = `[${stats.scanned}/${stats.total}]`;

    if (!FORCE && p.photoUrl && p.photoUrl.includes('thesportsdb.com')) {
      stats.skipped++;
      continue;
    }

    const parsed = parseName(p.name);
    if (!parsed) {
      stats.errors++;
      console.error(`${prefix} unparseable name: '${p.name}'`);
      continue;
    }

    try {
      // Strategy: try the surname alone first when the DB only has an
      // initial — searching "A. Abada" causes substring false-positives.
      // For full first-name rows, the full name is more selective so try
      // that first and fall back to the surname.
      const primary = parsed.firstInitial && !parsed.full.includes(' ')
        ? parsed.surname
        : parsed.full;
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
        continue;
      }

      const newUrl = match.strCutout || match.strThumb;
      if (!newUrl) {
        stats.noMatch++;
        console.log(`${prefix} hit but no image: ${p.name} → ${match.strPlayer}`);
        continue;
      }
      if (newUrl === p.photoUrl) {
        stats.skipped++;
        continue;
      }

      stats.matched++;
      console.log(`${prefix} ${p.name} → ${match.strPlayer} (${match.strTeam ?? '—'})  ${match.strCutout ? 'cutout' : 'thumb'}`);

      if (!DRY_RUN) {
        await prisma.$transaction([
          prisma.player.update({ where: { id: p.id }, data: { photoUrl: newUrl } }),
          prisma.cardTemplate.updateMany({
            where: { playerId: p.id },
            data: { artUrl: newUrl },
          }),
        ]);
        stats.updated++;
      }
    } catch (e) {
      stats.errors++;
      const msg = e instanceof Error ? e.message : String(e);
      console.error(`${prefix} ERROR ${p.name}: ${msg}`);
    }
  }

  console.log(`[refresh-photos] done`);
  console.log(`  scanned:   ${stats.scanned}`);
  console.log(`  matched:   ${stats.matched}`);
  console.log(`  updated:   ${stats.updated}${DRY_RUN ? ' (dry-run, no writes)' : ''}`);
  console.log(`  skipped:   ${stats.skipped}`);
  console.log(`  no-match:  ${stats.noMatch}`);
  console.log(`  rejected:  ${stats.rejected}`);
  console.log(`  errors:    ${stats.errors}`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
