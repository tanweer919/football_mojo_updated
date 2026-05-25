-- Add UserRole enum + role column on User.
-- Existing rows backfill to 'USER' via the DEFAULT — no data migration needed.

CREATE TYPE "UserRole" AS ENUM ('USER', 'ADMIN', 'SUPERADMIN');

ALTER TABLE "User"
  ADD COLUMN "role" "UserRole" NOT NULL DEFAULT 'USER';

-- Help the admin user list filter by role efficiently. Cardinality is tiny
-- (3 values) but admins are looked up by role on every signed-in admin
-- page render, so the index is worth it for the privileged-row case.
CREATE INDEX "User_role_idx" ON "User"("role");
