-- Public handle for user-to-user search ("jordan42").
-- Optional until claimed; stored lowercase so the unique index is
-- case-insensitive without needing CITEXT.

ALTER TABLE "User" ADD COLUMN "userTag" TEXT;

CREATE UNIQUE INDEX "User_userTag_key" ON "User"("userTag");
