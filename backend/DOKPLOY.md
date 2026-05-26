# Dokploy deploy runbook

End-to-end guide for deploying the FootballMojo backend to a Dokploy VPS.
Everything below is repeatable — running each step a second time is a no-op.

## What gets deployed

| Service  | What it does                                              | Replicas |
| -------- | --------------------------------------------------------- | -------- |
| `migrate`| One-shot `prisma migrate deploy`. Gates api + worker.     | 1        |
| `api`    | HTTP + WebSocket. Behind Traefik. Healthcheck on `/health`| 1–2      |
| `worker` | BullMQ scoring, FCM dispatcher, cron jobs (`WORKER_MODE`) | **1**    |

Plus, in a separate Dokploy-managed Postgres + Redis (Option A) **or** in
the same compose stack (Option B — see `docker-compose.prod.full.yml`).

The worker **must stay at 1 replica** — `@nestjs/schedule` cron jobs fire
from every process, and multiple workers would multiply WC-digest pushes,
bracket re-scores, and news-breaking notifications.

## Prerequisites

- A Dokploy VPS up and reachable. Any cloud — Hetzner CX22 (2 vCPU / 4 GB
  / €4/mo) is enough for launch.
- A domain pointed at the VPS (e.g. `api.pitch.app` → VPS IP).
- This repo accessible from Dokploy via GitHub/GitLab integration or a
  deploy key.
- A Firebase project for auth + FCM (service account JSON).
- An api-football account (or RapidAPI subscription).

## Option A — Dokploy managed Postgres + Redis (recommended)

Cleanest setup. Database lifecycle is independent of the app.

### 1. Provision the databases

In Dokploy → **Databases** → **Create**:

| | Postgres | Redis |
|--|--|--|
| Name | `footballmojo-pg` | `footballmojo-redis` |
| Image | `postgres:16-alpine` | `redis:7-alpine` |
| Memory | 512 MB | 256 MB |
| Password | autogenerate, copy it | autogenerate, copy it |
| External port | leave internal | leave internal |

Once each shows **Running**, click into it and copy the **Internal
Connection URL**. They look like:
```
postgresql://footballmojo:abc...@footballmojo-pg:5432/footballmojo
redis://:def...@footballmojo-redis:6379
```

### 2. Create the application

Dokploy → **Project** → **Create Application** → **Docker Compose**:

| Field | Value |
|--|--|
| Source | GitHub → this repo, branch `main` |
| Build Path | `backend` |
| Compose Path | `backend/docker-compose.prod.yml` |
| Auto Deploy | On (deploys on every push to `main`) |

### 3. Configure environment

Paste the contents of `backend/.env.production.example` into the
application's **Environment** tab, then fill in real values:

```env
NODE_ENV=production
PORT=3000

DATABASE_URL=postgresql://footballmojo:...@footballmojo-pg:5432/footballmojo?schema=public
REDIS_URL=redis://:...@footballmojo-redis:6379

CORS_ORIGINS=https://pitch.app,https://admin.pitch.app

API_FOOTBALL_PROVIDER=direct
API_FOOTBALL_KEY=<your api-football key>
API_FOOTBALL_WC_LEAGUE_ID=1
API_FOOTBALL_WC_SEASON=2026
SEED_REQUEST_DELAY_MS=250

FIREBASE_SERVICE_ACCOUNT_B64=<base64-encoded service account JSON>

POLL_INTERVAL_LIVE_MS=15000
POLL_INTERVAL_IDLE_MS=600000

NEWS_RSS_FEEDS=https://feeds.bbci.co.uk/sport/football/rss.xml,https://www.theguardian.com/football/rss,https://www.skysports.com/rss/12040,https://www.espn.com/espn/rss/soccer/news,https://www.fifa.com/rss-feeds/news
NEWS_REFRESH_INTERVAL_MS=600000
```

To base64 the Firebase service account on macOS:
```bash
base64 -i firebase-service-account.json | tr -d '\n'
```
or on Linux:
```bash
base64 -w 0 firebase-service-account.json
```

### 4. Attach the domain

Dokploy → Application → **Domains** → **Add**:
- Host: `api.pitch.app`
- Service: `api`
- Port: `3000`
- HTTPS: **on** (Let's Encrypt via Traefik)

### 5. First deploy

Click **Deploy**. Watch the logs in real time:

```
migrate-1   | Applying migration `20260519000000_add_fantasy_leagues`
migrate-1   | Applying migration `20260520000000_gem_ledger`
migrate-1   | Applying migration `20260521000000_card_scarcity`
migrate-1   | Applying migration `20260522000000_h2h_invite_links`
migrate-1   | Applying migration `20260523000000_notif_country_awards`
migrate-1   | Applying migration `20260524000000_notification_log_columns`
migrate-1   | All migrations have been successfully applied.
migrate-1 exited with code 0
api-1       | Nest application successfully started
worker-1    | FantasyScoringWorker — listening for jobs
worker-1    | FCM dispatcher listening on match:*:update / match:*:event
```

### 6. Verify

From your laptop:

```bash
cd backend
./scripts/dokploy-verify.sh https://api.pitch.app
```

You should see every probe go green. If `/health` returns 503, check that
`DATABASE_URL` and `REDIS_URL` actually resolve from inside the
application's network — that's the most common first-deploy mistake.

### 7. Seed data (one-time, after first deploy)

The simplest path is to run the seeds from your local machine, pointing
at the production database via a tunnel. From Dokploy → Postgres → "Add
External Port" temporarily, then:

```bash
cd backend
DATABASE_URL=postgresql://USER:PASS@VPS-IP:EXTERNAL-PORT/footballmojo \
  ./scripts/dokploy-seed.sh
```

The script is idempotent — re-running after a partial failure is safe.
Remove the external port after seeding.

Alternatively, exec into the api container via Dokploy → Application →
**Terminal** and run:
```bash
npm install --include=dev tsx       # tsx is a devDep, missing in prod image
./scripts/dokploy-seed.sh
```

## Option B — Postgres + Redis in the same compose

If you'd rather not use Dokploy's managed databases (cheaper, simpler
backups via volume snapshots):

In step 2, set **Compose Path** to `backend/docker-compose.prod.full.yml`
instead. In step 3, set `POSTGRES_PASSWORD` and `REDIS_PASSWORD` and use
the internal URLs:

```env
DATABASE_URL=postgresql://footballmojo:${POSTGRES_PASSWORD}@postgres:5432/footballmojo?schema=public
REDIS_URL=redis://:${REDIS_PASSWORD}@redis:6379
POSTGRES_PASSWORD=<strong-random>
REDIS_PASSWORD=<strong-random>
```

The rest of the flow is identical.

## Day-2 operations

### Subsequent deploys

Just push to `main`. With **Auto Deploy** on, Dokploy:
1. Pulls the new commit.
2. Rebuilds the image (cached layers reuse anything that didn't change).
3. Runs `migrate` — if it fails, the deploy aborts and old containers
   keep serving.
4. Recreates `api` + `worker` with the new image. Traefik routes the
   first healthy `api` container, then drains the old one.

To deploy from CLI without pushing:
```bash
curl -X POST "https://dokploy.example.com/api/applications/<id>/deploy" \
  -H "Authorization: Bearer $DOKPLOY_TOKEN"
```

### Preflight a deploy locally

Before pushing, run:
```bash
cd backend
./scripts/dokploy-preflight.sh
```
This validates the migrations, builds the TypeScript, optionally builds
the Docker image, and warns about env vars referenced in code that
aren't in `.env.production.example`. Catches almost every "the deploy
broke prod" mistake before it leaves your machine.

### Logs

Dokploy → Application → **Logs** for live tail. Or via Docker on the VPS:
```bash
docker logs -f --tail=100 footballmojo-api-1
docker logs -f --tail=100 footballmojo-worker-1
```

### Rolling back

Dokploy → Application → **Deployments** → click the previous successful
deploy → **Promote**. Migrations are NOT rolled back automatically —
they're additive in this codebase (nullable columns, new tables only), so
the previous app version tolerates the newer schema.

If you ever need to roll a migration back:
```bash
# From inside the api container or via local tunnel:
npx prisma migrate resolve --rolled-back 20260524000000_notification_log_columns
```
then write a follow-up migration that reverses the change. **Don't ever
edit a committed migration's SQL** — Prisma's checksum will refuse to
apply the next migration on every other replica.

### Backups

**Managed Postgres** (Option A): Dokploy auto-snapshots daily. Set
retention in the database's settings.

**In-stack Postgres** (Option B): set up a cron on the VPS:
```bash
0 4 * * * docker exec footballmojo-postgres-1 pg_dump -U footballmojo footballmojo \
  | gzip > /backups/footballmojo-$(date +\%F).sql.gz
```

### Scaling

To horizontally scale `api`:
- Dokploy → Application → **Advanced** → **Replicas: 2** (or more).
- Traefik load-balances across them automatically.
- Safe because `api` is stateless and BullMQ jobs all flow through Redis.

**Never** scale `worker` above 1 replica — see warning at top.

### Worker mode debugging

If scoring isn't happening / FCM pushes aren't firing, check that the
worker container actually has `WORKER_MODE=true`:
```bash
docker exec footballmojo-worker-1 env | grep WORKER_MODE
# WORKER_MODE=true
```
The compose file sets it via the `environment:` block — if it's missing,
something overrode it.

### Redis health

```bash
docker exec footballmojo-redis-1 redis-cli -a "$REDIS_PASSWORD" INFO replication
docker exec footballmojo-redis-1 redis-cli -a "$REDIS_PASSWORD" PING
```

Or via the app's health endpoint:
```bash
curl -s https://api.pitch.app/health | jq
# { "status": "ok", "db": "fulfilled", "redis": "fulfilled", ... }
```

## Common gotchas

| Symptom | Likely cause | Fix |
|---|---|---|
| `/health` returns 503 with `db: rejected` | `DATABASE_URL` wrong or Postgres not reachable from app network | Check Dokploy → Database → Status. Try `docker exec api-1 nc -vz <pg-host> 5432`. |
| `/health` returns 503 with `redis: rejected` | `REDIS_URL` wrong or Redis password mismatch | Same — `nc -vz`, then `redis-cli -h <host> -a <pwd> ping`. |
| Migrate container fails with `P3014` | Schema drift — someone edited DB out-of-band | Don't `prisma db push` against prod, ever. Resolve with `migrate resolve` after diffing. |
| Worker logs say "subscribed" but no pushes fire | FCM service account env not set OR breaking-news topic has no subscribers yet | `docker exec worker-1 env \| grep FIREBASE_SERVICE_ACCOUNT_B64`. From the app, opt into notifications. |
| `prisma generate` runs every deploy and slows builds | That's by design — it's in the build stage so the prod image has the freshly-typed client. ~3s, leave it. |
| Build OOMs on Dokploy | Default node-alpine + nest build needs ~1.2 GB. Bump VM RAM to ≥ 4 GB or add a swap file. |
| Card store returns `[]` | Seed scripts haven't run | `./scripts/dokploy-seed.sh` from a machine with `DATABASE_URL` set. |

## Files referenced

```
backend/
  Dockerfile                            # multi-stage build (deps → build → prod-deps → runtime)
  docker-compose.prod.yml               # app-tier, managed DB + Redis from Dokploy
  docker-compose.prod.full.yml          # all-in-one: Postgres + Redis + app in one stack
  .env.production.example               # paste into Dokploy Environment, fill in
  DOKPLOY.md                            # this file
  MIGRATIONS.md                         # per-migration notes + rollback guidance
  scripts/
    dokploy-preflight.sh                # pre-push: validates build + env coverage
    dokploy-verify.sh   <BASE_URL>      # post-deploy: probes every critical endpoint
    dokploy-seed.sh     [--light]       # idempotent seeds, runs in order
```
