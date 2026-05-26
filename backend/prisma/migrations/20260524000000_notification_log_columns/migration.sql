-- Extend NotificationLog so the in-app notification center can render
-- rich rows + an unread badge.
--   category   — match the user-facing categories (mojo.match / news / …)
--   title/body — denormalised from the original push for fast read
--   deepLink   — tap target
--   readAt     — drives the unread count + read-state badging
--
-- All nullable / additive — existing rows keep working untouched.

ALTER TABLE "NotificationLog"
  ADD COLUMN "category" TEXT,
  ADD COLUMN "title"    TEXT,
  ADD COLUMN "body"     TEXT,
  ADD COLUMN "deepLink" TEXT,
  ADD COLUMN "readAt"   TIMESTAMP(3);

CREATE INDEX "NotificationLog_userId_readAt_idx"
  ON "NotificationLog"("userId", "readAt");
