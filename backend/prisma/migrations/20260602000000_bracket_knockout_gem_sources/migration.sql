-- Add knockout-stage bracket pick gem sources. PostgreSQL requires each
-- new enum value to be added in its own ALTER TYPE statement.
--
-- Backward-compatible: no existing rows reference these values yet, so
-- the migration is a pure-add. Bracket re-scoring after deploy will
-- start writing them.

ALTER TYPE "GemSource" ADD VALUE 'BRACKET_R16_REACH';
ALTER TYPE "GemSource" ADD VALUE 'BRACKET_QF_REACH';
ALTER TYPE "GemSource" ADD VALUE 'BRACKET_SF_REACH';
ALTER TYPE "GemSource" ADD VALUE 'BRACKET_FINALIST';
