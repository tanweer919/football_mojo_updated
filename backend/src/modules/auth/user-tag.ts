import { randomBytes } from 'crypto';

import { Logger } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

import { mintWelcomeCard } from './welcome-card';

const log = new Logger('UserTag');

/// Public handle format — must match `TAG_PATTERN` in users.service.ts.
///   - lowercase letters, digits, dot, underscore
///   - 3 to 20 characters
///   - cannot start/end with `.` or `_`, no consecutive `..` or `__`
const TAG_PATTERN = /^(?![._])(?!.*[._]{2})[a-z0-9._]{3,20}(?<![._])$/;

/// Reserved handles users can never claim. Keep short — admin/legal/CS.
const RESERVED = new Set([
  'admin', 'pitch', 'support', 'help', 'team', 'staff',
  'official', 'system', 'root', 'me', 'you',
]);

/**
 * Generate a unique `userTag` for a brand-new user.
 *
 * Performance:
 *   - Happy path (clean base, no collision): **1 DB query** (`findMany IN`).
 *   - Collisions: 1 batched query of N candidates per attempt — never more
 *     than 3 attempts in practice (3 × 8 candidates = 24 tries before the
 *     base-36 fallback, which has 36^4 ≈ 1.7M-entry entropy).
 *
 * Race safety: this function ONLY reserves a candidate — the caller still has
 * to handle a `P2002` from the eventual `INSERT` because two concurrent
 * first-logins could both pass the same window. See `claimUserTagWithRetry`
 * below for the wrapper that handles that.
 */
export async function generateUniqueUserTag(
  prisma: PrismaClient,
  opts: { displayName?: string | null; email?: string | null },
): Promise<string> {
  const base = sanitiseBase(opts.displayName ?? opts.email ?? 'manager');

  // Build a batch of candidates and reject the ones already taken in a single
  // `WHERE userTag IN (…)` query — saves N-1 round-trips on collision.
  for (let attempt = 0; attempt < 3; attempt++) {
    const candidates = candidatesFor(base, attempt);
    const taken = await fetchTaken(prisma, candidates);
    for (const c of candidates) {
      if (!taken.has(c) && !RESERVED.has(c) && TAG_PATTERN.test(c)) {
        return c;
      }
    }
  }

  // Pathological collision space — fall back to crypto-random base36 (~1.7M
  // permutations of 4 chars + base-36 → effectively unbounded).
  for (let i = 0; i < 5; i++) {
    const candidate = `mgr_${randomBase36(6)}`;
    const taken = await fetchTaken(prisma, [candidate]);
    if (!taken.has(candidate)) return candidate;
  }

  // Last resort — append the timestamp; trivially unique.
  return trimToValid(`mgr_${Date.now().toString(36)}`);
}

/**
 * Atomically claim a generated tag. Wraps the INSERT in a retry loop that
 * regenerates the tag on `P2002 (userTag)` — covers the race-window where
 * two concurrent first-logins both pass `generateUniqueUserTag` for the
 * same candidate.
 *
 * Caller passes the row data minus `userTag`; we attach the tag and try
 * the create. Returns the tag that was eventually claimed.
 */
export async function createUserWithUniqueTag(
  prisma: PrismaClient,
  uid: string,
  opts: { email?: string | null; displayName?: string | null },
): Promise<string> {
  for (let attempt = 0; attempt < 4; attempt++) {
    const tag = await generateUniqueUserTag(prisma, opts);
    try {
      await prisma.user.create({
        data: {
          id: uid,
          email: opts.email ?? null,
          displayName: opts.displayName ?? null,
          userTag: tag,
        },
      });
      // Mint a one-off signup gift. Fire-and-log — never blocks signup.
      mintWelcomeCard(prisma, uid)
        .then((cardId) => {
          if (cardId) log.log(`welcome card minted for ${uid}: ${cardId}`);
        })
        .catch((err) => log.warn(`welcome card mint failed for ${uid}: ${(err as Error).message}`));
      return tag;
    } catch (e: any) {
      // P2002 = unique constraint violation. Could be on `id` (parallel
      // first-login for SAME firebase user — fine, row exists, exit) or on
      // `userTag` (a third user grabbed our candidate first — retry).
      const target = e?.meta?.target;
      const isUniqueViolation = e?.code === 'P2002';
      if (!isUniqueViolation) throw e;
      const isIdConflict = Array.isArray(target)
        ? target.includes('id')
        : typeof target === 'string' && target.includes('id');
      if (isIdConflict) {
        // Row already exists — fetch the existing tag instead of retrying.
        const existing = await prisma.user.findUnique({
          where: { id: uid },
          select: { userTag: true },
        });
        return existing?.userTag ?? tag;
      }
      // userTag conflict → loop and pick a new candidate.
    }
  }
  throw new Error('failed_to_claim_user_tag');
}

// ─── helpers ─────────────────────────────────────────────────────────────────

/// Build N candidate handles for a given base + attempt.
///   attempt 0 → [base, base + 2-digit, base + 3-digit] × 4
///   attempt 1 → base + 4-digit × 8
///   attempt 2 → base + 5-digit × 8
function candidatesFor(base: string, attempt: number): string[] {
  if (attempt === 0) {
    return [base, ...range(7).map(() => `${trimRoom(base, 2)}${randomDigits(2)}`)];
  }
  const digits = attempt === 1 ? 4 : 5;
  return range(8).map(() => `${trimRoom(base, digits)}${randomDigits(digits)}`);
}

function trimRoom(base: string, suffixLen: number): string {
  return trimToValid(base.slice(0, 20 - suffixLen));
}

async function fetchTaken(
  prisma: PrismaClient,
  candidates: string[],
): Promise<Set<string>> {
  const rows = await prisma.user.findMany({
    where: { userTag: { in: candidates } },
    select: { userTag: true },
  });
  return new Set(rows.map((r) => r.userTag).filter((t): t is string => t !== null));
}

function sanitiseBase(raw: string): string {
  let s = raw.toLowerCase();
  if (s.includes('@')) s = s.split('@', 1)[0];
  s = s
    .normalize('NFKD').replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9._]/g, '.')
    .replace(/[._]{2,}/g, '.')
    .replace(/^[._]+|[._]+$/g, '');
  if (s.length > 20) s = s.slice(0, 20).replace(/[._]+$/g, '');
  if (s.length < 3) s = 'manager';
  return s;
}

function trimToValid(s: string): string {
  let out = s.replace(/[._]+$/g, '').slice(0, 20).replace(/[._]+$/g, '');
  if (out.length < 3) out = (out + 'fan').slice(0, 20);
  return out;
}

function randomDigits(n: number): string {
  const buf = randomBytes(n);
  let out = '';
  for (let i = 0; i < n; i++) out += (buf[i] % 10).toString();
  return out;
}

/// crypto-grade base36 of length n (~5.2 bits/char).
function randomBase36(n: number): string {
  const alpha = 'abcdefghijklmnopqrstuvwxyz0123456789';
  const buf = randomBytes(n);
  let out = '';
  for (let i = 0; i < n; i++) out += alpha[buf[i] % 36];
  return out;
}

function range(n: number): number[] {
  return Array.from({ length: n }, (_, i) => i);
}
