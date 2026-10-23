-- CreateEnum
CREATE TYPE "DailyDietScope" AS ENUM ('DAY', 'WEEK', 'MONTH');

-- AlterTable
ALTER TABLE "DailyDietContent" ADD COLUMN     "scope" "DailyDietScope" NOT NULL DEFAULT 'DAY';
