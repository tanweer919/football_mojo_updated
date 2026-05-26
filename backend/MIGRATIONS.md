# Migration runbook

Migrations land in `prisma/migrations/` and are applied with Prisma's standard
deploy command. None of the migrations below require a manual backfill — they
add nullable columns / new tables only, so the database can take them while
the old version of the API is still running.

## Recent migrations (apply in order)

| Migration                                          | What it does                                                                                                | Rollback                                                                                              |
| -------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `20260519000000_add_fantasy_leagues`               | New tables `FantasyLeague` + `FantasyLeagueMember` for private league membership.                           | `DROP TABLE` both tables. No FK from other tables points back, so safe.                               |
| `20260520000000_gem_ledger`                        | `GemSource` enum + `GemTransaction` ledger + `User.lastDailyClaimAt`.                                       | Drop table + column. `User.gems` keeps its existing integer so balances aren't lost.                  |
| `20260521000000_card_scarcity`                     | `CardTemplate.dropOpensAt`, `dropClosesAt`, `maxPerUser` (all nullable).                                    | `DROP COLUMN` — defaults to "always open, no cap", matching pre-migration behaviour.                  |
| `20260522000000_h2h_invite_links`                  | `H2HChallenge.opponentId` relaxed to NULL + new `inviteToken String? @unique`.                              | Hard rollback would have to backfill `opponentId`; **avoid rolling back** once invites are live.      |

## Deploy order

```bash
# 1. Apply database schema
cd backend
npx prisma migrate deploy

# 2. Regenerate the Prisma client so the running process picks up new types
npx prisma generate

# 3. Restart the API + worker pods
#    (no extra environment variables required by these migrations)
```

If `prisma generate` is part of your build (it is — `nest build` calls it
transitively in the existing CI workflow), step 2 is redundant.

## Seed scripts (optional, run after migrations)

```bash
# Stage-locked WC editions for the gem store — requires base templates first.
npm run seed:cards         # 1) base WC cards (one per player)
npm run seed:wc-stages     # 2) Group → R32 → R16 → QF → SF → Final editions
```

Both seeds are idempotent — safe to re-run.

## Rolling back

For column-add / table-add migrations, the API tolerates the column not
existing (Prisma client doesn't query columns it doesn't know about). So:

1. Roll the API back **first** to the previous release.
2. Then roll the schema back with `prisma migrate resolve --rolled-back <name>`.

The single migration that's harder to roll back is `20260522000000_h2h_invite_links` —
production data with `opponentId = NULL` would violate a re-tightened NOT NULL.
If you absolutely need to roll back, first delete all open invites:
`DELETE FROM "H2HChallenge" WHERE "opponentId" IS NULL;` before re-adding the
NOT NULL constraint.

## After-deploy verification

```bash
# Gem ledger is wired
curl -s "$API/v1/gems/catalog" | jq .

# Bracket endpoints
curl -s "$API/v1/predictions/bracket/leaderboard?competitionId=WC2026" | jq .

# Card scarcity surfacing
curl -s "$API/v1/cards/store/featured" | jq '.[0]'

# Private leagues require auth — smoke via Firebase ID token:
curl -s -H "Authorization: Bearer $TOKEN" "$API/v1/fantasy/leagues/mine" | jq .
```

## Worker mode

The bracket scoring tick + fantasy scoring queue run only when the process
has `WORKER_MODE=true` set. Make sure exactly one pod has that env var,
otherwise nothing scores. (Local dev assumes worker mode unless
`NODE_ENV=production` is set.)
