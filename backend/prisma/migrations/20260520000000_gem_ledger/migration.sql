-- Gem economy ledger + daily-login timestamp on User.
--
-- The in-memory `User.gems` integer is treated as a cache of SUM(amount)
-- for that user in this table. Every credit/debit is recorded with a
-- source enum and an optional ref pair so we can audit anything.
-- A dedupe unique key on (userId, source, refType, refId) prevents the
-- same scoring run from awarding the same gems twice on a re-run.

CREATE TYPE "GemSource" AS ENUM (
  'PREDICTION_CORRECT',
  'PREDICTION_EXACT',
  'FANTASY_RANK',
  'BRACKET_GROUP_WINNER',
  'BRACKET_RUNNER_UP',
  'BRACKET_CHAMPION',
  'DAILY_LOGIN',
  'IAP_PURCHASE',
  'CARD_PACK_PURCHASE',
  'PROFILE_FLAIR',
  'ADJUSTMENT'
);

CREATE TABLE "GemTransaction" (
  "id"            TEXT       NOT NULL,
  "userId"        TEXT       NOT NULL,
  "amount"        INTEGER    NOT NULL,
  "source"        "GemSource" NOT NULL,
  "description"   TEXT,
  "refType"       TEXT,
  "refId"         TEXT,
  "balanceAfter"  INTEGER    NOT NULL,
  "createdAt"     TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "GemTransaction_pkey" PRIMARY KEY ("id")
);

CREATE INDEX        "GemTransaction_userId_createdAt_idx"
  ON "GemTransaction"("userId", "createdAt");
CREATE UNIQUE INDEX "GemTransaction_userId_source_refType_refId_key"
  ON "GemTransaction"("userId", "source", "refType", "refId");

ALTER TABLE "GemTransaction"
  ADD CONSTRAINT "GemTransaction_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "User"
  ADD COLUMN "lastDailyClaimAt" TIMESTAMP(3);
