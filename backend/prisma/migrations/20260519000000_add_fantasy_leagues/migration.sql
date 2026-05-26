-- Private friend leagues inside Fantasy tournaments.
-- Membership-only — scoring still flows through FantasyLineup; leagues just
-- filter which users to rank against each other.

CREATE TABLE "FantasyLeague" (
  "id"           TEXT NOT NULL,
  "tournamentId" TEXT NOT NULL,
  "ownerId"      TEXT NOT NULL,
  "name"         TEXT NOT NULL,
  "joinCode"     TEXT NOT NULL,
  "memberLimit"  INTEGER NOT NULL DEFAULT 100,
  "createdAt"    TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "FantasyLeague_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "FantasyLeague_joinCode_key" ON "FantasyLeague"("joinCode");
CREATE INDEX        "FantasyLeague_tournamentId_idx" ON "FantasyLeague"("tournamentId");

ALTER TABLE "FantasyLeague"
  ADD CONSTRAINT "FantasyLeague_tournamentId_fkey"
    FOREIGN KEY ("tournamentId") REFERENCES "FantasyTournament"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT "FantasyLeague_ownerId_fkey"
    FOREIGN KEY ("ownerId")      REFERENCES "User"("id")              ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "FantasyLeagueMember" (
  "id"        TEXT NOT NULL,
  "leagueId"  TEXT NOT NULL,
  "userId"    TEXT NOT NULL,
  "joinedAt"  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "FantasyLeagueMember_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "FantasyLeagueMember_leagueId_userId_key" ON "FantasyLeagueMember"("leagueId", "userId");
CREATE INDEX        "FantasyLeagueMember_userId_idx"          ON "FantasyLeagueMember"("userId");

ALTER TABLE "FantasyLeagueMember"
  ADD CONSTRAINT "FantasyLeagueMember_leagueId_fkey"
    FOREIGN KEY ("leagueId") REFERENCES "FantasyLeague"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT "FantasyLeagueMember_userId_fkey"
    FOREIGN KEY ("userId")   REFERENCES "User"("id")          ON DELETE CASCADE ON UPDATE CASCADE;
