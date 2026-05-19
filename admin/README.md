# PITCH Admin

Internal admin panel for FootballMojo / PITCH.
**Next.js 14 + Firebase Auth (same Firebase project as the Flutter app) → NestJS backend (`/v1/admin/*`).**
No direct DB access from Next.js; every read and write goes through the backend.

## Architecture

```
            ┌────────────────┐         ┌──────────────────────┐         ┌────────────┐
  Browser → │ Next.js (3001) │ proxy → │ NestJS backend (3000)│ Prisma →│ Postgres   │
            └────────────────┘         └──────────────────────┘         └────────────┘
                  ↑                            ↑
                  │                            │
            Firebase JS SDK             FirebaseAuthGuard
            (Google popup)              + AdminRoleGuard
```

| Concern | Where it lives |
|---|---|
| Sign-in (Google popup) | Browser — `firebase/auth` |
| ID-token storage       | httpOnly cookie `pitch_admin_id_token`, set by `/api/session` |
| Role check (ADMIN / SUPERADMIN) | Backend — `AdminRoleGuard` on every admin controller |
| Token verification     | Backend — same `FirebaseAuthGuard` the mobile app already uses |
| All mutations (player edit, role change, etc.) | Backend services — Next.js just proxies |
| Data fetches           | Server components call backend via `apiServer()`; client components via `api()` (proxied through `/api/admin/*`) |

There is **one** trust boundary: the NestJS backend. The Next.js layer can't be tricked into corrupting data because it doesn't have database credentials — it forwards the user's Firebase ID token to backend endpoints that do their own auth.

## First-time setup

```bash
cd admin
cp .env.example .env
# Fill in BACKEND_URL + NEXT_PUBLIC_FIREBASE_* (see below)

npm install     # no prisma generate — we don't talk to the DB directly
```

### Required env

| Var                                | Why                                                                                       |
|------------------------------------|-------------------------------------------------------------------------------------------|
| `BACKEND_URL`                      | Where the NestJS backend is reachable from the Next.js server. Docker compose: `http://api:3000`. Locally: `http://localhost:3000`. |
| `NEXT_PUBLIC_FIREBASE_API_KEY`     | Same Firebase project as the Flutter app — pull from Firebase console.                    |
| `NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN` | Usually `<project-id>.firebaseapp.com`. **Add `localhost:3001` and your prod domain** to Firebase console → Authentication → Settings → Authorized domains. |
| `NEXT_PUBLIC_FIREBASE_PROJECT_ID`  |                                                                                           |
| `NEXT_PUBLIC_FIREBASE_APP_ID`      | Web app id from Firebase console.                                                         |

No NextAuth, no Prisma, no service account file in the admin app. The Firebase web config is intentionally public — Firebase's docs confirm there's nothing to keep secret in `apiKey` / `appId` (real auth happens in your security rules + backend role check).

## Granting access

1. Make sure the user has signed in to the mobile app at least once (so their `User` row exists). If they haven't, the next step will create an admin-only shell.
2. From the backend folder:

   ```bash
   cd ../backend
   npm run admin:promote -- you@example.com           # → ADMIN
   npm run admin:promote -- you@example.com -- --super   # → SUPERADMIN
   npm run admin:promote -- you@example.com -- --demote  # → USER
   ```

3. Open `http://localhost:3001/login` and sign in with that Google account.

Once you have at least one SUPERADMIN, additional admins can be invited from `/users` in the UI — no shell access required.

## Running

```bash
npm run dev          # localhost:3001 (so it doesn't clash with backend on 3000)
npm run typecheck    # tsc --noEmit
npm run build && npm run start
```

The backend must be running on `BACKEND_URL` for the admin to do anything useful.

## Sections

| Route             | Talks to                                | Notes |
|-------------------|-----------------------------------------|-------|
| `/dashboard`      | `GET /v1/admin/{me, stats}`              | KPIs + photo-coverage panel |
| `/players`        | `GET /v1/admin/players`                  | Paginated list, search, photo filter |
| `/players/[id]`   | `GET, PATCH /v1/admin/players/:id`<br/>`POST /v1/admin/players/:id/refresh-photo` | Photo URL editor with live PCard preview. PATCH on the backend wraps `Player.photoUrl` + every `CardTemplate.artUrl` in one transaction. `refresh-photo` runs the same TheSportsDB heuristics as the bulk `refresh:photos` script, for one row. |
| `/cards`          | `GET /v1/admin/cards`                    | All `CardTemplate` rows |
| `/cards/[id]`     | `GET, PATCH /v1/admin/cards/:id`         | Edit edition / rarity / supply / art / purchasable. `mintedCount` is read-only; backend rejects supply < minted. |
| `/teams`          | `GET /v1/admin/teams`                    | List + competition filter |
| `/teams/[id]`     | `GET, PATCH /v1/admin/teams/:id`         | Crest, country, primary colour |
| `/users`          | `GET /v1/admin/users`<br/>`PATCH /v1/admin/users/:id/role`<br/>`POST /v1/admin/users/invite` | SUPERADMIN can promote/demote/invite. Plain ADMIN reads only. |

## How the auth flow actually works

1. User clicks "Continue with Google" → `signInWithPopup` (Firebase JS SDK) → user object with `getIdToken()`.
2. Browser POSTs `{ idToken }` to `/api/session`.
3. `/api/session` calls `GET /v1/admin/me` on the backend with `Authorization: Bearer <token>` — this is the existing `FirebaseAuthGuard` + new `AdminRoleGuard` doing both jobs (verify signature *and* check role). If it 200s, the user is an admin.
4. `/api/session` sets the ID token as `pitch_admin_id_token` (httpOnly, samesite=lax, 75 min).
5. Every server component reads the cookie via `next/headers`, forwards it as `Authorization: Bearer …` to backend.
6. Every client component routes its mutations through `/api/admin/[...path]/route.ts`, which reads the cookie and proxies to backend.
7. `<TokenRefresher>` listens to `onIdTokenChanged` and re-POSTs to `/api/session` ~every 50 min so the cookie stays fresh.

### Why store the ID token directly (vs. Firebase session cookies)?

Firebase session cookies are great for long-lived web sessions, but they're not valid as `Authorization: Bearer` tokens for the existing `FirebaseAuthGuard`. Using the raw ID token means **one verification path on the backend** — the same code path the mobile app uses — instead of teaching the guard a second verification mode just for the admin.

The trade-off is that we have to refresh the cookie every hour. `<TokenRefresher>` makes that automatic, and a stale token is no worse than a stale Firebase session cookie (both → re-sign-in).

## What `admin/` deliberately doesn't do

- **No Prisma client.** `@prisma/client` isn't even in `package.json`. The data layer is the backend.
- **No business logic in server actions.** Mutations are thin wrappers around `api()` / `apiServer()` calls.
- **No NextAuth.** Replaced by a Firebase ID-token cookie + backend role check.
- **No match / competition / fantasy CRUD.** Those entities are owned by ingest workers; hand-editing would clobber the next sync. Use the backend's seed scripts.

## Adding a new admin surface

1. **Backend:** add a controller method under `backend/src/modules/admin/` wired through `FirebaseAuthGuard` + `AdminRoleGuard`. Stick `@RequireRole('SUPERADMIN')` on it if it needs the higher tier.
2. **Admin:** add a server-component page that calls `apiServer<T>('/admin/your-thing')`. If it has mutations, add a client island that calls `api<T>('/your-thing', { method: 'PATCH', body: JSON.stringify(...) })`.
3. **Nav:** add a row to `src/lib/nav.ts`.

## Deployment

The admin is a stateless Next.js app. Host anywhere (Vercel, Fly, Railway, a Docker host). Its only external dependency is the backend at `BACKEND_URL`. No DB connection from the admin host.
