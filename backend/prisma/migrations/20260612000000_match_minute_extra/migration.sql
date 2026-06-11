-- Stoppage / added time for live matches, e.g. the "4" in "45+4".
ALTER TABLE "Match" ADD COLUMN "minuteExtra" INTEGER;
