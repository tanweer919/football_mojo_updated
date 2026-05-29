# syntax=docker/dockerfile:1.7

# ─── Base image ──────────────────────────────────────────────────────────────
FROM node:22.18.0-alpine AS base
WORKDIR /app
# - openssl: needed by Prisma at runtime
# - libc6-compat: shims glibc-style binary deps (some Prisma engines need it on musl)
# - tini: PID-1 init so the api/worker propagates signals cleanly under Docker/Dokploy
# - wget: HEALTHCHECK probe (busybox wget is included; explicit for clarity)
# - bash: Dokploy's terminal feature default-execs `bash`; without this the
#   "OCI runtime exec failed: exec: bash" error blocks easy in-container debugging.
# - postgresql-client: for one-off `psql` checks against managed Postgres
#   (DB connectivity smoke-test, manual seed runs). ~6 MB, worth the size.
RUN apk add --no-cache openssl libc6-compat tini wget bash postgresql-client

# ─── Full dependencies for build ──────────────────────────────────────────────
FROM base AS deps
COPY package.json package-lock.json* ./
COPY prisma ./prisma
RUN npm ci

# ─── Compile TypeScript ──────────────────────────────────────────────────────
FROM deps AS build
COPY tsconfig*.json nest-cli.json ./
COPY src ./src
# Fail loudly if `nest build` ever exits clean but doesn't produce main.js.
RUN npx prisma generate \
 && npm run build \
 && test -f dist/main.js \
 || (echo "❌ Build did not produce dist/main.js" && ls -la dist/ 2>/dev/null && exit 1)

# ─── Production dependencies only ─────────────────────────────────────────────
# Strips devDependencies (typescript, nest cli, eslint, ts-node, jest...).
# Keeps @prisma/client and prisma (the CLI used by `migrate deploy`).
FROM base AS prod-deps
COPY package.json package-lock.json* ./
COPY prisma ./prisma
RUN npm ci --omit=dev \
 && npx prisma generate \
 && npm cache clean --force

# ─── Runtime image ───────────────────────────────────────────────────────────
FROM base AS runtime
ENV NODE_ENV=production

# Build args propagated as image labels for traceability (Dokploy passes these via
# its build settings; locally they're optional).
ARG BUILD_REF=local
ARG BUILD_DATE
LABEL org.opencontainers.image.title="FootballMojo Backend" \
      org.opencontainers.image.description="Realtime scores, fantasy, cards, predictions backend" \
      org.opencontainers.image.revision="${BUILD_REF}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.licenses="UNLICENSED"

COPY --from=prod-deps /app/node_modules ./node_modules
COPY --from=build     /app/dist         ./dist
COPY --from=build     /app/prisma       ./prisma
COPY package.json ./

# Run as non-root: any CVE in a Node dep that achieves code-exec can't `chown /`.
RUN addgroup -S app && adduser -S app -G app && chown -R app:app /app
USER app

EXPOSE 3000

# Healthcheck: api exposes /health (db + redis ping); worker has no HTTP — its
# compose service overrides this with a process check.
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health || exit 1

# tini gets a clean SIGTERM to Node so Nest's enableShutdownHooks() runs
# (closes Redis, Prisma, Socket.IO before SIGKILL hits).
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "dist/main.js"]
