-- "Where to watch" broadcast links per match. ADMIN rows are curated;
-- SCRAPER rows are bulk-ingested and replaced wholesale on each ingest.

CREATE TYPE "WatchLinkSource" AS ENUM ('ADMIN', 'SCRAPER');

CREATE TABLE "WatchLink" (
  "id"          TEXT NOT NULL,
  "matchId"     TEXT NOT NULL,
  "name"        TEXT NOT NULL,
  "url"         TEXT,
  "countryCode" TEXT,
  "countryName" TEXT,
  "logoUrl"     TEXT,
  "source"      "WatchLinkSource" NOT NULL DEFAULT 'ADMIN',
  "position"    INTEGER NOT NULL DEFAULT 0,
  "createdAt"   TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt"   TIMESTAMP(3) NOT NULL,
  CONSTRAINT "WatchLink_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "WatchLink_matchId_idx" ON "WatchLink"("matchId");

ALTER TABLE "WatchLink"
  ADD CONSTRAINT "WatchLink_matchId_fkey"
  FOREIGN KEY ("matchId") REFERENCES "Match"("id") ON DELETE CASCADE ON UPDATE CASCADE;
