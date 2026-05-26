#!/usr/bin/env bash
# Run BEFORE pushing to git for a Dokploy deploy. Validates that the local
# checkout has the bits Dokploy will need + the build doesn't blow up.
#
# Exits non-zero on any failure so you can chain into a git push:
#   ./scripts/dokploy-preflight.sh && git push origin main
set -Eeuo pipefail

cd "$(dirname "$0")/.."

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { printf "  ${GREEN}✓${NC} %s\n" "$1"; }
warn() { printf "  ${YELLOW}!${NC} %s\n" "$1"; }
err()  { printf "  ${RED}✗${NC} %s\n" "$1"; exit 1; }
step() { printf "\n${YELLOW}▶${NC} %s\n" "$1"; }

step "Sanity checks"
[[ -f Dockerfile ]]                            || err "Dockerfile missing"
[[ -f docker-compose.prod.yml ]]               || err "docker-compose.prod.yml missing"
[[ -f .env.production.example ]]               || err ".env.production.example missing"
[[ -d prisma/migrations ]]                     || err "prisma/migrations missing"
[[ -f package.json ]]                          || err "package.json missing"
ok "All required files present"

step "Migrations"
mig_count=$(find prisma/migrations -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
ok "$mig_count migrations on disk"
# Each migration dir must have a migration.sql or Prisma will fail to apply.
missing=$(find prisma/migrations -mindepth 1 -maxdepth 1 -type d ! -exec test -f {}/migration.sql \; -print)
if [[ -n "$missing" ]]; then err "Migration dirs missing migration.sql: $missing"; fi
ok "Every migration has a migration.sql"

step "TypeScript build"
npm install --omit=optional --no-audit --no-fund >/dev/null 2>&1 || warn "npm install warnings (above)"
npx prisma generate >/dev/null 2>&1            || err "prisma generate failed"
npm run build >/dev/null                       || err "nest build failed"
[[ -f dist/main.js ]]                          || err "dist/main.js missing after build"
ok "Backend builds clean"

step "Docker image build"
if ! command -v docker >/dev/null 2>&1; then
  warn "docker not installed locally — skipping image build check"
elif ! docker info >/dev/null 2>&1; then
  warn "docker daemon not running — skipping image build check (start Docker Desktop to verify locally)"
else
  if docker build --target runtime -t footballmojo-backend:preflight . >/tmp/dokploy-build.log 2>&1; then
    ok "Image builds (footballmojo-backend:preflight)"
  else
    tail -20 /tmp/dokploy-build.log
    err "Docker image build failed — see output above. Full log at /tmp/dokploy-build.log"
  fi
fi

step "Env template diff"
# Catch new env vars in source that aren't documented in the example.
# Best-effort grep — false positives are OK (warn, not error).
src_vars=$(grep -rhE "cfg\.(getOrThrow|get)<string>\('[A-Z_]+'" src 2>/dev/null \
  | grep -oE "'[A-Z_]+'" | tr -d "'" | sort -u)
doc_vars=$(grep -oE "^[A-Z_]+=" .env.production.example | tr -d '=' | sort -u)
missing_docs=$(comm -23 <(echo "$src_vars") <(echo "$doc_vars") || true)
if [[ -n "$missing_docs" ]]; then
  warn "env vars in src not in .env.production.example:"
  echo "$missing_docs" | sed 's/^/      /'
else
  ok "All env vars referenced in src are documented"
fi

printf "\n${GREEN}Preflight OK.${NC} Safe to push.\n\n"
printf "Next steps:\n"
printf "  1. git add -A && git commit -m 'deploy: <message>' && git push\n"
printf "  2. Dokploy will pick up the new commit and run docker compose build + up.\n"
printf "  3. After deploy, run:  ./scripts/dokploy-verify.sh https://<your-domain>\n\n"
