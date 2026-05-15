# Production deploy (Dokploy)

This backend ships two long-running services (`api`, `worker`) and one one-shot
(`migrate`). Postgres + Redis are NOT in the production Compose — use Dokploy's
managed Database feature for both.

## One-time setup on Dokploy

### 1. Provision the databases

Dashboard → **Databases** → Create:

| Database | Engine | Notes |
|---|---|---|
| `footballmojo-pg` | Postgres 16 | Backups enabled; expose only on the internal Dokploy network |
| `footballmojo-redis` | Redis 7 | Persistence: AOF; default config is fine |

Copy the connection strings — you'll paste them into the app's env in step 3.

### 2. Create the application

Dashboard → **Applications** → New Compose-style app:

| Field | Value |
|---|---|
| Source | Git repo `footballmojo` |
| Branch | `main` (or whichever you ship from) |
| Build context | `backend/` |
| Compose file | `backend/docker-compose.prod.yml` |
| Auto-deploy on push | Optional but recommended |

### 3. Environment

Paste every entry from [`backend/.env.example`](.env.example) into the
**Environment** tab, substituting real values:

```
NODE_ENV=production
PORT=3000

DATABASE_URL=postgresql://<user>:<pw>@footballmojo-pg:5432/footballmojo?schema=public
REDIS_URL=redis://default:<pw>@footballmojo-redis:6379

API_FOOTBALL_PROVIDER=direct          # or rapidapi
API_FOOTBALL_KEY=<your real key>
API_FOOTBALL_WC_LEAGUE_ID=1
API_FOOTBALL_WC_SEASON=2026
SEED_REQUEST_DELAY_MS=250

FIREBASE_SERVICE_ACCOUNT_B64=<base64 of the service-account JSON>

POLL_INTERVAL_LIVE_MS=15000
POLL_INTERVAL_IDLE_MS=600000

NEWS_RSS_FEEDS=https://feeds.bbci.co.uk/sport/football/rss.xml,https://www.theguardian.com/football/rss,https://www.skysports.com/rss/12040,https://www.espn.com/espn/rss/soccer/news,https://www.fifa.com/rss-feeds/news
NEWS_REFRESH_INTERVAL_MS=600000

CORS_ORIGINS=https://api.footballmojo.app,https://footballmojo.app
```

Dokploy generates a `.env` from these values inside the build container at deploy time.

### 4. Domain + Traefik

Dokploy auto-attaches Traefik. In the **Domains** tab of the application:

- Host: `api.footballmojo.app`
- Container port: `3000`
- HTTPS: on (Let's Encrypt)
- HTTP → HTTPS redirect: on
- WebSocket support: **on** — required for Socket.IO `/realtime` path

### 5. First deploy

Click **Deploy**.

Order of operations (handled by Compose `depends_on`):

1. Image builds (3–6 min on Colima, ~2 min on bare metal)
2. `migrate` container starts → applies any unapplied migrations → exits 0
3. `api` and `worker` start
4. Traefik picks up the healthy `api` and routes the domain to it

Watch the logs:

```bash
# From the Dokploy UI Logs tab — or via SSH:
docker compose -f backend/docker-compose.prod.yml logs -f migrate
docker compose -f backend/docker-compose.prod.yml logs -f api
docker compose -f backend/docker-compose.prod.yml logs -f worker
```

### 6. Seed data (one-time)

Run from the Dokploy terminal (or SSH into the host):

```bash
docker compose -f backend/docker-compose.prod.yml run --rm api npm run seed
```

Takes ~3 minutes on RapidAPI free, ~30 sec on Pro. Watch for "✓ Seed complete".

## Routine operations

### Deploy a new release

Push to the tracked branch. Dokploy auto-builds and re-runs the compose:

- `migrate` applies any new migration files committed in the repo
- `api` and `worker` get rolling-restarted

Zero downtime is achievable if you have ≥2 api replicas behind Traefik. Single-replica deploys are ~5–10 sec down while the new container becomes healthy.

### Roll back

Dokploy keeps the last N images. **Applications → History → Rollback to <commit>**.

If a schema migration was part of the rollback, you'll need to revert the migration manually — Prisma doesn't auto-rollback. Generate a counter-migration:

```bash
npx prisma migrate dev --name revert_xyz
# Edit the SQL to undo, commit, deploy
```

### Inspect the worker's BullMQ queue

```bash
docker compose -f backend/docker-compose.prod.yml exec worker node -e "
const { Queue } = require('bullmq');
const IORedis = require('ioredis');
const c = new IORedis(process.env.REDIS_URL);
const q = new Queue('fantasy-scoring', { connection: c });
q.getJobCounts().then(console.log).then(() => process.exit(0));
"
```

### Connect to the DB

```bash
# From the host where Dokploy runs
docker compose -f backend/docker-compose.prod.yml exec api npx prisma studio
```

(Prisma Studio's port has to be tunneled — usually easier to use a local Studio against an SSH-forwarded DB port.)

## Lessons baked into this Compose

These are mistakes we hit during local development that are now structurally impossible:

| Past pain | Permanent fix |
|---|---|
| `nest build` silently produced no `dist/main.js` | Dockerfile has `test -f dist/main.js` guard. Build fails loudly instead of producing a broken image |
| Container restart-loops when migration files don't exist | Dedicated `migrate` service runs once, `depends_on: service_completed_successfully` gates api/worker |
| Postgres 15 P1010 on the `public` schema | Dokploy-managed Postgres handles this. Dev compose has `db/init/01-grants.sql` for fresh local volumes |
| `prisma migrate dev` shadow-DB permission failures | Production uses `migrate deploy` (no shadow DB needed). Dev migrations created on host and committed |
| Stale Docker layer cache hiding TS errors | Dokploy builds with `--no-cache` on each release by default. `BUILD_REF` arg busts the cache on each commit |
| Lockfile drift breaking `npm ci` | `npm ci --omit=dev` in `prod-deps` stage enforces lockfile match before image is built |
| Container running as root | Runtime image has a non-privileged `app` user; Nest runs as it |
| Signals not reaching Node (zombie procs after `docker stop`) | `tini` is `ENTRYPOINT`; Nest's `enableShutdownHooks()` runs cleanly on SIGTERM |
| Seed reaching into `src/` that's not in the runtime image | Seed inlines the two helpers it needed. Image stays lean |
| Production image bloat from devDependencies | Separate `prod-deps` stage runs `npm ci --omit=dev`. ~250 MB → ~140 MB |

## Failure mode reference

| Symptom | Likely cause | Fix |
|---|---|---|
| Deploy stuck on "starting" | Healthcheck failing — `/health` not 200 | Check `docker compose logs api` for Postgres/Redis connection errors |
| `migrate` exits non-zero | New migration broken or DB perms wrong | Read the `migrate` container log; in dev, `npx prisma migrate dev` against a fresh DB to reproduce |
| `worker` healthcheck reports unhealthy | Crash loop on Redis disconnect | Check `REDIS_URL`; Dokploy Redis must accept connections from app subnet |
| 502 from Traefik | `api` not healthy yet | Wait 30 sec for first healthcheck; or `docker compose ps` to see status |
| FCM pushes don't arrive | `FIREBASE_SERVICE_ACCOUNT_B64` missing or malformed | `docker compose exec api node -e "console.log(JSON.parse(Buffer.from(process.env.FIREBASE_SERVICE_ACCOUNT_B64,'base64').toString()).project_id)"` should print your project id |
| api-football 429s during seed | RapidAPI free tier rate-limit | Bump `SEED_REQUEST_DELAY_MS` to 2500. Or upgrade tier |

## Resource budget on a 28 GB Dokploy VM

| Component | Reserved | Limit |
|---|---|---|
| `api`           | 0.25 cpu / 256 MB | 1.0 cpu / 1 GB |
| `worker`        | 0.5 cpu / 768 MB  | 1.5 cpu / 1.5 GB |
| Postgres (Dokploy) | 0.5 cpu / 1 GB | 2.0 cpu / 4 GB (tune in Dokploy DB settings) |
| Redis (Dokploy) | 0.1 cpu / 128 MB  | 0.5 cpu / 1 GB |
| **Total**       | ~1.4 cpu / 2.2 GB | **~5 cpu / 7.5 GB** |

Leaves ~20 GB headroom for Dokploy itself + OS + burst capacity during scoring storms.
