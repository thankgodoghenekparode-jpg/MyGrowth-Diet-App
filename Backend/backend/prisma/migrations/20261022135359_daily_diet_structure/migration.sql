-- CreateEnum
CREATE TYPE "DailyDietBehaviour" AS ENUM ('TEXT', 'MATERIAL', 'TIMER', 'TICK', 'REPORT', 'PARTNER');

-- CreateTable
CREATE TABLE "DailyDietSection" (
    "id" UUID NOT NULL,
    "programmeId" UUID NOT NULL,
    "key" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "description" TEXT,
    "behaviour" "DailyDietBehaviour" NOT NULL DEFAULT 'TEXT',
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "required" BOOLEAN NOT NULL DEFAULT true,
    "allowNote" BOOLEAN NOT NULL DEFAULT true,
    "trackCompletion" BOOLEAN NOT NULL DEFAULT true,
    "status" "ContentStatus" NOT NULL DEFAULT 'DRAFT',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "DailyDietSection_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DailyDietContent" (
    "id" UUID NOT NULL,
    "sectionId" UUID NOT NULL,
    "date" DATE NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT,
    "details" JSONB,
    "materialIds" JSONB,
    "externalUrl" TEXT,
    "durationTargetMinutes" INTEGER,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "status" "ContentStatus" NOT NULL DEFAULT 'DRAFT',
    "publishedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "DailyDietContent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DailyDietCompletion" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "sectionId" UUID NOT NULL,
    "date" DATE NOT NULL,
    "status" "ActivityRecordStatus" NOT NULL DEFAULT 'NOT_STARTED',
    "note" TEXT,
    "actualDurationMinutes" INTEGER,
    "actualQuantity" INTEGER,
    "completedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "DailyDietCompletion_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "DailyDietSection_programmeId_sortOrder_idx" ON "DailyDietSection"("programmeId", "sortOrder");

-- CreateIndex
CREATE INDEX "DailyDietSection_status_idx" ON "DailyDietSection"("status");

-- CreateIndex
CREATE UNIQUE INDEX "DailyDietSection_programmeId_key_key" ON "DailyDietSection"("programmeId", "key");

-- CreateIndex
CREATE INDEX "DailyDietContent_date_idx" ON "DailyDietContent"("date");

-- CreateIndex
CREATE UNIQUE INDEX "DailyDietContent_sectionId_date_key" ON "DailyDietContent"("sectionId", "date");

-- CreateIndex
CREATE INDEX "DailyDietCompletion_userId_date_idx" ON "DailyDietCompletion"("userId", "date");

-- CreateIndex
CREATE INDEX "DailyDietCompletion_sectionId_date_idx" ON "DailyDietCompletion"("sectionId", "date");

-- CreateIndex
CREATE UNIQUE INDEX "DailyDietCompletion_userId_sectionId_date_key" ON "DailyDietCompletion"("userId", "sectionId", "date");

-- AddForeignKey
ALTER TABLE "DailyDietSection" ADD CONSTRAINT "DailyDietSection_programmeId_fkey" FOREIGN KEY ("programmeId") REFERENCES "Programme"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DailyDietContent" ADD CONSTRAINT "DailyDietContent_sectionId_fkey" FOREIGN KEY ("sectionId") REFERENCES "DailyDietSection"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DailyDietCompletion" ADD CONSTRAINT "DailyDietCompletion_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DailyDietCompletion" ADD CONSTRAINT "DailyDietCompletion_sectionId_fkey" FOREIGN KEY ("sectionId") REFERENCES "DailyDietSection"("id") ON DELETE CASCADE ON UPDATE CASCADE;
