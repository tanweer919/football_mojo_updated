-- Country supporter + notification preferences + award pick'em.
-- All three features in one migration since they share rollout cadence
-- and none of them require a backfill.

-- 1) User.supportedCountryCode — distinct from `countryCode` (nationality).
ALTER TABLE "User"
  ADD COLUMN "supportedCountryCode" TEXT;

-- 2) NotificationPreference — lazily created on first write. Defaults
--    mean "everything on" so absence-of-row = no opt-out.
CREATE TABLE "NotificationPreference" (
  "userId"            TEXT NOT NULL,
  "matchGoals"        BOOLEAN NOT NULL DEFAULT true,
  "matchKickoff"      BOOLEAN NOT NULL DEFAULT true,
  "matchFulltime"     BOOLEAN NOT NULL DEFAULT true,
  "matchLineup"       BOOLEAN NOT NULL DEFAULT true,
  "breakingNews"      BOOLEAN NOT NULL DEFAULT true,
  "wcDailyRecap"      BOOLEAN NOT NULL DEFAULT true,
  "fantasyResults"    BOOLEAN NOT NULL DEFAULT true,
  "h2hInvites"        BOOLEAN NOT NULL DEFAULT true,
  "h2hResults"        BOOLEAN NOT NULL DEFAULT true,
  "cardDrops"         BOOLEAN NOT NULL DEFAULT true,
  "updatedAt"         TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "NotificationPreference_pkey" PRIMARY KEY ("userId")
);

ALTER TABLE "NotificationPreference"
  ADD CONSTRAINT "NotificationPreference_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- 3) AwardPick + AwardType enum — tournament-end awards pick'em.
CREATE TYPE "AwardType" AS ENUM (
  'GOLDEN_BOOT',
  'GOLDEN_BALL',
  'BEST_YOUNG_PLAYER'
);

CREATE TABLE "AwardPick" (
  "id"             TEXT NOT NULL,
  "userId"         TEXT NOT NULL,
  "competitionId"  TEXT NOT NULL,
  "awardType"      "AwardType" NOT NULL,
  "playerId"       TEXT NOT NULL,
  "pointsAwarded"  INTEGER NOT NULL DEFAULT 0,
  "scoredAt"       TIMESTAMP(3),
  "lockedAt"       TIMESTAMP(3),
  "createdAt"      TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt"      TIMESTAMP(3) NOT NULL,

  CONSTRAINT "AwardPick_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "AwardPick_userId_competitionId_awardType_key"
  ON "AwardPick"("userId", "competitionId", "awardType");
CREATE INDEX "AwardPick_competitionId_awardType_idx"
  ON "AwardPick"("competitionId", "awardType");

ALTER TABLE "AwardPick"
  ADD CONSTRAINT "AwardPick_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT "AwardPick_playerId_fkey"
    FOREIGN KEY ("playerId") REFERENCES "Player"("id") ON DELETE CASCADE ON UPDATE CASCADE;
