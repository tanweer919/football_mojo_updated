-- One-notify-per-article guard. The RSS aggregator runs on every server
-- instance (no worker gate), so each instance independently fired the team /
-- breaking pushes — N instances = N duplicate notifications. An atomic claim on
-- this column (UPDATE ... WHERE notifiedAt IS NULL) lets exactly one instance
-- win and send.

ALTER TABLE "NewsArticle" ADD COLUMN "notifiedAt" TIMESTAMP(3);
