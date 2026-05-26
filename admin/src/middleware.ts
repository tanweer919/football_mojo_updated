import { NextResponse, type NextRequest } from 'next/server';
import { SESSION_COOKIE } from '@/lib/session';

/**
 * Lightweight route guard. We only check for the *presence* of the
 * session cookie here — full verification (Firebase signature + admin
 * role) happens server-side when the page makes its first backend call.
 *
 * That trade is deliberate:
 *   - Middleware runs on every request, including static asset bypasses.
 *     Verifying a Firebase token (network call to Google's JWKS endpoint
 *     or a firebase-admin round-trip) adds ~50-200ms to every navigation.
 *   - The cookie is httpOnly + same-site, and the only way to mint it is
 *     `/api/session` which itself calls the backend (which double-checks
 *     token validity AND admin role). A forged cookie won't fool the
 *     backend even if it gets past the middleware.
 */
export function middleware(req: NextRequest) {
  const { nextUrl } = req;
  const hasSession = !!req.cookies.get(SESSION_COOKIE);
  const isLogin = nextUrl.pathname.startsWith('/login');

  if (isLogin) {
    if (hasSession) return NextResponse.redirect(new URL('/dashboard', nextUrl));
    return NextResponse.next();
  }
  if (!hasSession) {
    const url = new URL('/login', nextUrl);
    if (nextUrl.pathname !== '/') url.searchParams.set('from', nextUrl.pathname);
    return NextResponse.redirect(url);
  }
  return NextResponse.next();
}

export const config = {
  // Don't run on /api/* (the session + admin-proxy routes handle their own
  // auth) or on static asset routes.
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico).*)'],
};
