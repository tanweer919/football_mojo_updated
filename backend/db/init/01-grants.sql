-- Runs ONCE on a fresh Postgres volume (handled by the official image's
-- /docker-entrypoint-initdb.d hook).
-- Fixes the Postgres 15+ default where the `public` schema doesn't grant
-- CREATE/USAGE to the database owner automatically.

GRANT ALL ON SCHEMA public TO footballmojo;
ALTER SCHEMA public OWNER TO footballmojo;
