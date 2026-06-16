-- Per-match FIFA-official YouTube highlight link, curated by an admin once the
-- match is finished. Nullable: most matches have no highlight until set.

ALTER TABLE "Match" ADD COLUMN "highlightUrl" TEXT;
