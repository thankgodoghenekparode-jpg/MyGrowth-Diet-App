-- AlterTable
ALTER TABLE "Programme" ADD COLUMN     "annualReflectionTemplate" JSONB,
ADD COLUMN     "quarterlyConfession" TEXT,
ADD COLUMN     "quarterlyReviewTopics" JSONB;
