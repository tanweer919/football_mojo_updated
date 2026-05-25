-- Welcome-card tracking — set when the user dismisses the reveal screen.
ALTER TABLE "User" ADD COLUMN "welcomeCardSeenAt" TIMESTAMP(3);

-- Acquisition source for the signup gift.
ALTER TYPE "AcquisitionSource" ADD VALUE IF NOT EXISTS 'SIGNUP_GIFT';
