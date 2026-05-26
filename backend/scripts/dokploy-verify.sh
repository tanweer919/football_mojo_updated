#!/usr/bin/env bash
# Run AFTER a Dokploy deploy. Hits the public URL and verifies every
# critical surface is responding correctly. Use:
#   ./scripts/dokploy-verify.sh https://api.pitch.app
#
# Exits non-zero if any required endpoint fails, so you can chain it in
# CI as a post-deploy gate.
set -Eeuo pipefail

BASE="${1:-}"
if [[ -z "$BASE" ]]; then
  echo "Usage: $0 https://your-api-domain"
  exit 2
fi
BASE="${BASE%/}"  # strip trailing slash

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()    { printf "  ${GREEN}✓${NC} %s\n" "$1"; }
warn()  { printf "  ${YELLOW}!${NC} %s\n" "$1"; }
fail()  { printf "  ${RED}✗${NC} %s\n" "$1"; FAILED=$((FAILED+1)); }
step()  { printf "\n${YELLOW}▶${NC} %s\n" "$1"; }

FAILED=0

# Helper: GET, store status + body in vars STATUS / BODY.
probe() {
  local url="$1"
  local resp
  resp=$(curl -fsS -o /tmp/dokploy-verify.body -w "%{http_code}" "$url" 2>/dev/null || echo "000")
  STATUS="$resp"
  BODY=$(cat /tmp/dokploy-verify.body 2>/dev/null || true)
}

step "Liveness"
probe "$BASE/health/liveness"
[[ "$STATUS" == "200" ]] && ok "/health/liveness → 200" || fail "/health/liveness → $STATUS"

step "Full health (DB + Redis)"
probe "$BASE/health"
if [[ "$STATUS" == "200" ]]; then
  ok "/health → 200 ($BODY)"
elif [[ "$STATUS" == "503" ]]; then
  fail "/health → 503 — DB or Redis is down ($BODY)"
else
  fail "/health → $STATUS (network or proxy issue)"
fi

step "Public endpoints"
for path in \
  "/v1/gems/catalog" \
  "/v1/cards/store/featured" \
  "/v1/h2h/ladder" \
  "/v1/predictions/bracket/leaderboard?competitionId=WC2026" \
  "/v1/news?limit=1" \
  ; do
  probe "$BASE$path"
  if [[ "$STATUS" =~ ^2 ]]; then
    ok "GET $path → $STATUS"
  else
    fail "GET $path → $STATUS"
  fi
done

step "Versioned route prefix"
probe "$BASE/v1/awards/candidates?competitionId=WC2026&awardType=GOLDEN_BOOT&limit=1"
[[ "$STATUS" =~ ^2 ]] && ok "Awards module reachable" || fail "Awards module unreachable ($STATUS)"

step "CORS preflight"
cors_status=$(curl -fsS -o /dev/null -w "%{http_code}" \
  -X OPTIONS "$BASE/v1/news" \
  -H "Origin: https://pitch.app" \
  -H "Access-Control-Request-Method: GET" 2>/dev/null || echo "000")
if [[ "$cors_status" =~ ^2 ]]; then
  ok "CORS preflight from https://pitch.app → $cors_status"
else
  warn "CORS preflight returned $cors_status — set CORS_ORIGINS in Dokploy env"
fi

echo
if [[ "$FAILED" -gt 0 ]]; then
  printf "${RED}FAILED: $FAILED check(s).${NC} See logs above.\n"
  exit 1
fi
printf "${GREEN}All checks passed.${NC} Deploy is healthy at $BASE\n\n"
printf "Next steps if first deploy:\n"
printf "  - ./scripts/dokploy-seed.sh   # seed WC roster, cards, stage editions, prefs\n"
printf "  - Configure FCM topics in Firebase Console (news_breaking, wc_digest_*)\n"
printf "  - Smoke-test from the mobile app: sign in → check inbox → make a bracket pick\n\n"
