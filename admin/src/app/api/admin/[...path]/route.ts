import { NextResponse, type NextRequest } from 'next/server';
import { SESSION_COOKIE } from '@/lib/session';

/**
 * Transparent proxy from `/api/admin/<path>` → `<BACKEND_URL>/v1/admin/<path>`.
 *
 * Why proxy through Next.js instead of letting the browser hit the backend
 * directly:
 *   1. The Firebase ID token lives in an httpOnly cookie. The browser
 *      can't read it; the proxy can. No client-side token handling means
 *      no `await user.getIdToken()` sprinkled across every component.
 *   2. CORS preflights vanish — we're same-origin.
 *   3. One single place to bolt on logging / rate limiting later if needed.
 *
 * The proxy is stateless — it just forwards method + body + the auth
 * cookie. Every business decision (role check, validation, transactions)
 * still happens on the backend.
 */

const BACKEND = process.env.BACKEND_URL ?? 'http://localhost:3000';

async function proxy(req: NextRequest, { params }: { params: { path: string[] } }) {
  const token = req.cookies.get(SESSION_COOKIE)?.value;
  if (!token) {
    return NextResponse.json({ error: 'unauthenticated' }, { status: 401 });
  }

  // Backend uses `setGlobalPrefix('api')` + URI versioning, so the real
  // route shape is `/api/v1/admin/...`.
  const target = `${BACKEND}/api/v1/admin/${params.path.join('/')}${req.nextUrl.search}`;
  const body = req.method === 'GET' || req.method === 'HEAD'
    ? undefined
    : await req.text();

  const upstream = await fetch(target, {
    method: req.method,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': req.headers.get('content-type') ?? 'application/json',
    },
    body,
    cache: 'no-store',
  });

  const text = await upstream.text();
  return new NextResponse(text, {
    status: upstream.status,
    headers: {
      'Content-Type': upstream.headers.get('content-type') ?? 'application/json',
    },
  });
}

export const GET    = proxy;
export const POST   = proxy;
export const PATCH  = proxy;
export const PUT    = proxy;
export const DELETE = proxy;
