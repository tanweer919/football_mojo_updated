-- Season-stat columns on PlayerValuation. Source: api-football's
-- /players?league=X&season=Y `statistics` block. Used by the pricer to
-- compute realistic prices pre-WC even when PlayerGameweekScore is empty.

ALTER TABLE "PlayerValuation"
  ADD COLUMN "seasonRating"      DOUBLE PRECISION,
  ADD COLUMN "seasonAppearances" INTEGER,
  ADD COLUMN "seasonGoals"       INTEGER,
  ADD COLUMN "seasonAssists"     INTEGER,
  ADD COLUMN "seasonMinutes"     INTEGER,
  ADD COLUMN "seasonSampled"     INTEGER;
