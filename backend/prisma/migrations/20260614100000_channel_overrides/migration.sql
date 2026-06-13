-- Global per-channel watch-link overrides, keyed by broadcaster name. Applied
-- at serve time to every WatchLink with a matching name.

CREATE TABLE "ChannelOverride" (
  "id"        TEXT NOT NULL,
  "name"      TEXT NOT NULL,
  "url"       TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "ChannelOverride_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "ChannelOverride_name_key" ON "ChannelOverride"("name");
