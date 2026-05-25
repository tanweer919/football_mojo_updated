import { NextResponse, type NextRequest } from 'next/server';
import { SESSION_COOKIE, SESSION_MAX_AGE_S } from '@/lib/session';

/**
 * Session shim:
 *
 *   POST /api/session  { idToken }
 *     - Forward the token to `/v1/admin/stats` on the backend to verify
 *       it's both valid Firebase + maps to an ADMIN/SUPERADMIN row.
 *     - On 200, set the token as an httpOnly cookie so server components
 *       can pick it up via `readSessionToken()` for downstream backend
 *       fetches.
 *     - On 4xx, return the backend's status so the login UI can show
 *       "not an admin" vs "bad token".
 *
 *   DELETE /api/session
 *     - Clear the cookie (sign-out). Firebase client-side sign-out is
 *       handled separately in the topbar form.
 *
 * No business logic lives here — verification + role check stay on the
 * backend so there's exactly one trust boundary.
 */

const BACKEND = process.env.BACKEND_URL ?? 'http://localhost:3000';

export async function POST(req: NextRequest) {
  let idToken: string | undefined;
  try {
    ({ idToken } = await req.json());
  } catch {
    return NextResponse.json({ error: 'malformed_body' }, { status: 400 });
  }
  if (!idToken || typeof idToken !== 'string') {
    return NextResponse.json({ error: 'missing_token' }, { status: 400 });
  }

  // Ping a guarded endpoint with the token; if it 200s, the user is both
  // authenticated AND has at least ADMIN role. We use `/admin/me` since
  // it's the cheapest double-gated read (single Prisma findUnique).
  //
  // Backend mounts everything under `/api/v1/*` (setGlobalPrefix + URI
  // versioning), so the full path is `/api/v1/admin/me`.
  const verify = await fetch(`${BACKEND}/api/v1/admin/me`, {
    headers: { Authorization: `Bearer ${idToken}` },
    cache: 'no-store',
  });
  if (verify.status === 401) {
    return NextResponse.json({ error: 'invalid_token' }, { status: 401 });
  }
  if (verify.status === 403) {
    return NextResponse.json({ error: 'not_an_admin' }, { status: 403 });
  }
  if (!verify.ok) {
    return NextResponse.json({ error: 'backend_unavailable', status: verify.status }, { status: 502 });
  }

  const res = NextResponse.json({ ok: true });
  res.cookies.set({
    name: SESSION_COOKIE,
    value: idToken,
    httpOnly: true,
    sameSite: 'lax',
    secure: process.env.NODE_ENV === 'production',
    path: '/',
    maxAge: SESSION_MAX_AGE_S,
  });
  return res;
}

export async function DELETE() {
  const res = NextResponse.json({ ok: true });
  res.cookies.delete(SESSION_COOKIE);
  return res;
}
