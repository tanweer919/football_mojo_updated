-- OwnedCard progression + identity columns.
-- Backwards compatible: all defaulted so existing rows keep working.

ALTER TABLE "OwnedCard"
  ADD COLUMN "mintReason"      TEXT,
  ADD COLUMN "lifetimeGoals"   INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "lifetimeAssists" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "lifetimeMinutes" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "lifetimeApps"    INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "xp"              INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN "trophies"        TEXT[]  NOT NULL DEFAULT ARRAY[]::TEXT[];

-- Showcase / pinned card on user profile.
-- onDelete: SET NULL so deleting a card doesn't cascade-nuke the profile.
ALTER TABLE "User"
  ADD COLUMN "pinnedCardId" TEXT,
  ADD CONSTRAINT "User_pinnedCardId_fkey"
    FOREIGN KEY ("pinnedCardId") REFERENCES "OwnedCard"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Set Master template reference on CardSet.
-- onDelete: SET NULL so deleting the template gracefully clears the link.
ALTER TABLE "CardSet"
  ADD COLUMN "masterTemplateId" TEXT,
  ADD CONSTRAINT "CardSet_masterTemplateId_fkey"
    FOREIGN KEY ("masterTemplateId") REFERENCES "CardTemplate"("id") ON DELETE SET NULL ON UPDATE CASCADE;
