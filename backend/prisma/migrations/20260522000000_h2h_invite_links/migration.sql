-- Open invite links for H2H challenges.
--   inviteToken — URL-safe 16-char unique string for shareable links
--   opponentId  — relaxed to NULL so a challenge can exist before anyone
--                 has accepted the invite. Backfilled (every existing row
--                 already has an opponentId) so nothing breaks.

ALTER TABLE "H2HChallenge"
  ALTER COLUMN "opponentId" DROP NOT NULL,
  ADD COLUMN "inviteToken" TEXT;

CREATE UNIQUE INDEX "H2HChallenge_inviteToken_key" ON "H2HChallenge"("inviteToken");
