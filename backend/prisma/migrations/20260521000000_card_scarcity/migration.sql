-- Card scarcity primitives on CardTemplate:
--   dropOpensAt  — window opens (null = always open)
--   dropClosesAt — window closes forever (null = no close)
--   maxPerUser   — per-account cap (null = unlimited)
--
-- All nullable + defaulted-omitted so existing templates keep their
-- "open forever, no cap" behaviour without a backfill.

ALTER TABLE "CardTemplate"
  ADD COLUMN "dropOpensAt"  TIMESTAMP(3),
  ADD COLUMN "dropClosesAt" TIMESTAMP(3),
  ADD COLUMN "maxPerUser"   INTEGER;
