-- Track who set a match's highlight link so the auto-matcher never overwrites
-- a link an admin curated by hand (e.g. an embeddable source from another
-- rights-holder when the FIFA upload has embedding disabled).

CREATE TYPE "HighlightSource" AS ENUM ('AUTO', 'ADMIN');

ALTER TABLE "Match" ADD COLUMN "highlightSource" "HighlightSource";
