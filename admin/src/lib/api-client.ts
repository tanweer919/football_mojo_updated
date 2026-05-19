'use client';

import { firebaseAuth } from './firebase-client';

/**
 * Browser-side fetch wrapper. Routes through `/api/admin/*` on Next.js so
 * the httpOnly cookie comes along automatically — no need to grab the ID
 * token client-side and tack it onto every request.
 *
 * The Next.js proxy is implemented by `app/api/admin/[...path]/route.ts`,
 * which forwards to the backend with `Authorization: Bearer <cookie>`.
 *
 * Returns the parsed JSON body. Throws on non-2xx with the backend's error
 * payload so caller code can `.catch(e => e.message)`.
 */

export class ApiError extends Error {
  constructor(public status: number, public body: unknown, message: string) {
    super(message);
  }
}

export async function api<T>(path: string, init: RequestInit = {}): Promise<T> {
  const res = await fetch(`/api/admin${path}`, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...(init.headers ?? {}),
    },
    credentials: 'same-origin',
  });
  if (res.status === 401) {
    // The cookie expired mid-session — kick the user back through the
    // sign-in flow rather than swallowing a confusing failure.
    await firebaseAuth().signOut().catch(() => {});
    window.location.href = '/login';
    throw new ApiError(401, null, 'session_expired');
  }
  if (!res.ok) {
    let body: unknown = null;
    try { body = await res.json(); } catch { body = await res.text().catch(() => null); }
    const msg = (body as { message?: string } | null)?.message ?? `Request failed (${res.status})`;
    throw new ApiError(res.status, body, msg);
  }
  if (res.status === 204) return undefined as T;
  return (await res.json()) as T;
}
