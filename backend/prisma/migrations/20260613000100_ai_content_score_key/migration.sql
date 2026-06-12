-- Scoreline the cached live summary was generated for, so a goal can trigger a
-- refresh (regenerate when the score changes) without re-running on every tick.
ALTER TABLE "AiContent" ADD COLUMN "scoreKey" TEXT;
