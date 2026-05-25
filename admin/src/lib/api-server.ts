import 'server-only';
import { readSessionToken } from './session';

/**
 * Server-only fetch wrapper. Reads the session cookie via `next/headers`,
 * attaches `Authorization: Bearer <idToken>`, and points at the backend.
 *
 * Use from server components, route handlers, and server actions. For
 * client-component calls use `api-client.ts` (which reaches into the
 * Firebase JS SDK to grab a fresh ID token on the fly).
 *
 * On 401/403 we throw a typed `BackendError` so the page can decide
 * whether to redirect to /login (cookie expired) or surface a friendly
 * error (e.g. trying to do a SUPERADMIN-only action as ADMIN).
 */

const BACKEND = process.env.BACKEND_URL ?? 'http://localhost:3000';

export class BackendError extends Error {
  constructor(public status: number, public body: unknown, message: string) {
    super(message);
  }
}

export async function apiServer<T>(
  path: string,
  init?: RequestInit,
): Promise<T> {
  const token = readSessionToken();
  // Backend uses `setGlobalPrefix('api')` + URI versioning (defaultVersion: '1'),
  // so all routes live under `/api/v1/...`. Callers pass paths without the
  // version segment (e.g. `/admin/me`) and we splice the prefix in here.
  const res = await fetch(`${BACKEND}/api/v1${path}`, {
    ...init,
    headers: {
      ...(init?.headers ?? {}),
      Authorization: token ? `Bearer ${token}` : '',
      'Content-Type': 'application/json',
    },
    cache: 'no-store',
  });
  if (!res.ok) {
    let body: unknown = null;
    try { body = await res.json(); } catch { body = await res.text().catch(() => null); }
    throw new BackendError(res.status, body, `Backend ${res.status} on ${path}`);
  }
  if (res.status === 204) return undefined as T;
  return (await res.json()) as T;
}
