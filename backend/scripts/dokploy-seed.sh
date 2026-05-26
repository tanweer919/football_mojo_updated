#!/usr/bin/env bash
# Seed data into the deployed database. Runs every seed in the correct
# order. Idempotent — safe to re-run after any deploy.
#
# Two ways to run:
#
#   A) From your local machine, pointed at the prod DB via tunnel:
#        DATABASE_URL=postgresql://USER:PASS@PROD-HOST:5432/DB \
#          ./scripts/dokploy-seed.sh
#
#   B) Inside the running api container (Dokploy → Application → Terminal):
#        ./scripts/dokploy-seed.sh
#      The container has node + the seed scripts copied via the build stage,
#      and reads DATABASE_URL from its env.
#
# This script uses `tsx` (a devDep) which is NOT in the production runtime
# image (prod-deps stage runs `npm ci --omit=dev`). For Option B you'll
# need to either:
#   - One-off install in the container:  npm install --include=dev tsx
#   - Or run from your dev box (Option A) which is simpler.
set -Eeuo pipefail

cd "$(dirname "$0")/.."

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { printf "  ${GREEN}✓${NC} %s\n" "$1"; }
step() { printf "\n${YELLOW}▶${NC} %s\n" "$1"; }
err()  { printf "  ${RED}✗${NC} %s\n" "$1"; exit 1; }

[[ -n "${DATABASE_URL:-}" ]] || err "DATABASE_URL is required"

# Skip the heavy roster/cards seeds when --light is passed — useful for
# preview deploys that just need the schema migrated.
LIGHT=0
[[ "${1:-}" == "--light" ]] && LIGHT=1

step "Notification preference defaults"
npm run seed:notification-prefs
ok "Notification prefs seeded"

if [[ "$LIGHT" == "1" ]]; then
  printf "\nLight seed complete (skipped roster/cards/stage editions).\n"
  exit 0
fi

step "WC tournament shell (competition + teams + groups)"
npm run seed:wc
ok "WC2026 seeded"

step "WC roster (player photos)"
npm run seed:roster
ok "Roster seeded — wait ~30s for api-football rate limits"

step "Card templates per player"
npm run seed:cards
ok "Card templates minted"

step "Stage-locked card editions (Group → Final)"
npm run seed:wc-stages
ok "Stage editions seeded"

printf "\n${GREEN}All seeds complete.${NC}\n"
printf "Verify the gem store is populated:\n"
printf "  curl -s \$API_BASE/v1/cards/store/featured | jq 'length'\n\n"
