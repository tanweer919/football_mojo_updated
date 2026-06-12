-- Lifecycle phase of the cached AI content (preview → live → final).
ALTER TABLE "AiContent" ADD COLUMN "phase" TEXT;
