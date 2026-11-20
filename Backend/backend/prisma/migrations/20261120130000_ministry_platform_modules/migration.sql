-- CreateEnum
CREATE TYPE "GivingType" AS ENUM ('GENERAL_OFFERING', 'TITHE', 'MINISTRY_PARTNERSHIP', 'SPECIAL_SEED', 'MINISTRY_PROJECT', 'THANKSGIVING', 'OTHER');

-- CreateEnum
CREATE TYPE "GivingPaymentStatus" AS ENUM ('PENDING', 'PAID', 'FAILED', 'REFUNDED');

-- CreateEnum
CREATE TYPE "GivingPartnerFrequency" AS ENUM ('WEEKLY', 'MONTHLY', 'QUARTERLY', 'ANNUALLY');

-- CreateEnum
CREATE TYPE "GivingPartnerStatus" AS ENUM ('ACTIVE', 'PAUSED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "EventCategory" AS ENUM ('CHURCH_SERVICE', 'PRAYER_MEETING', 'CONFERENCE', 'SPECIAL_PROGRAMME', 'BIBLE_STUDY', 'FASTING_PROGRAMME', 'ONLINE_MEETING', 'OTHER_EVENT');

-- CreateEnum
CREATE TYPE "EventStatus" AS ENUM ('DRAFT', 'PUBLISHED', 'CANCELLED', 'COMPLETED');

-- CreateEnum
CREATE TYPE "StreamPlatform" AS ENUM ('YOUTUBE', 'FACEBOOK', 'OTHER_PLATFORM');

-- CreateEnum
CREATE TYPE "LiveServiceStatus" AS ENUM ('SCHEDULED', 'LIVE', 'ENDED');

-- CreateTable
CREATE TABLE "GivingCategory" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "type" "GivingType" NOT NULL,
    "description" TEXT,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "GivingCategory_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "GivingTransaction" (
    "id" UUID NOT NULL,
    "userId" UUID,
    "categoryId" UUID NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "currency" VARCHAR(3) NOT NULL DEFAULT 'NGN',
    "paymentReference" TEXT NOT NULL,
    "monnifyReference" TEXT,
    "status" "GivingPaymentStatus" NOT NULL DEFAULT 'PENDING',
    "donorName" TEXT,
    "donorEmail" TEXT,
    "donorPhone" TEXT,
    "isGuest" BOOLEAN NOT NULL DEFAULT false,
    "note" VARCHAR(500),
    "receiptNumber" TEXT,
    "paidAt" TIMESTAMP(3),
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "GivingTransaction_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "GivingPartner" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "currency" VARCHAR(3) NOT NULL DEFAULT 'NGN',
    "frequency" "GivingPartnerFrequency" NOT NULL,
    "status" "GivingPartnerStatus" NOT NULL DEFAULT 'ACTIVE',
    "startDate" DATE NOT NULL,
    "nextDueDate" DATE,
    "note" VARCHAR(500),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "GivingPartner_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "UpcomingEvent" (
    "id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "category" "EventCategory" NOT NULL,
    "bannerFileId" UUID,
    "venue" TEXT,
    "meetingLink" TEXT,
    "minister" TEXT,
    "startDate" TIMESTAMP(3) NOT NULL,
    "endDate" TIMESTAMP(3),
    "timezone" TEXT NOT NULL DEFAULT 'Africa/Lagos',
    "registrationRequired" BOOLEAN NOT NULL DEFAULT false,
    "maxAttendees" INTEGER,
    "status" "EventStatus" NOT NULL DEFAULT 'DRAFT',
    "createdById" UUID,
    "publishedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "UpcomingEvent_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "EventRegistration" (
    "id" UUID NOT NULL,
    "eventId" UUID NOT NULL,
    "userId" UUID,
    "guestName" TEXT,
    "guestEmail" TEXT,
    "guestPhone" TEXT,
    "isGuest" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "EventRegistration_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "LiveService" (
    "id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "minister" TEXT,
    "platform" "StreamPlatform" NOT NULL DEFAULT 'YOUTUBE',
    "streamUrl" TEXT,
    "embedUrl" TEXT,
    "thumbnailFileId" UUID,
    "status" "LiveServiceStatus" NOT NULL DEFAULT 'SCHEDULED',
    "scheduledAt" TIMESTAMP(3) NOT NULL,
    "startedAt" TIMESTAMP(3),
    "endedAt" TIMESTAMP(3),
    "timezone" TEXT NOT NULL DEFAULT 'Africa/Lagos',
    "isRecording" BOOLEAN NOT NULL DEFAULT false,
    "createdById" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "LiveService_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PrayerRequest" (
    "id" UUID NOT NULL,
    "liveServiceId" UUID,
    "userId" UUID,
    "name" TEXT NOT NULL,
    "email" TEXT,
    "phone" TEXT,
    "request" TEXT NOT NULL,
    "isGuest" BOOLEAN NOT NULL DEFAULT false,
    "isRead" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PrayerRequest_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "GivingCategory_name_key" ON "GivingCategory"("name");

-- CreateIndex
CREATE INDEX "GivingCategory_isActive_sortOrder_idx" ON "GivingCategory"("isActive", "sortOrder");

-- CreateIndex
CREATE UNIQUE INDEX "GivingTransaction_paymentReference_key" ON "GivingTransaction"("paymentReference");

-- CreateIndex
CREATE UNIQUE INDEX "GivingTransaction_monnifyReference_key" ON "GivingTransaction"("monnifyReference");

-- CreateIndex
CREATE UNIQUE INDEX "GivingTransaction_receiptNumber_key" ON "GivingTransaction"("receiptNumber");

-- CreateIndex
CREATE INDEX "GivingTransaction_userId_createdAt_idx" ON "GivingTransaction"("userId", "createdAt");

-- CreateIndex
CREATE INDEX "GivingTransaction_status_createdAt_idx" ON "GivingTransaction"("status", "createdAt");

-- CreateIndex
CREATE INDEX "GivingTransaction_categoryId_createdAt_idx" ON "GivingTransaction"("categoryId", "createdAt");

-- CreateIndex
CREATE INDEX "GivingTransaction_paidAt_idx" ON "GivingTransaction"("paidAt");

-- CreateIndex
CREATE INDEX "GivingPartner_status_frequency_idx" ON "GivingPartner"("status", "frequency");

-- CreateIndex
CREATE INDEX "GivingPartner_nextDueDate_idx" ON "GivingPartner"("nextDueDate");

-- CreateIndex
CREATE UNIQUE INDEX "GivingPartner_userId_key" ON "GivingPartner"("userId");

-- CreateIndex
CREATE INDEX "UpcomingEvent_status_startDate_idx" ON "UpcomingEvent"("status", "startDate");

-- CreateIndex
CREATE INDEX "UpcomingEvent_category_idx" ON "UpcomingEvent"("category");

-- CreateIndex
CREATE INDEX "UpcomingEvent_startDate_idx" ON "UpcomingEvent"("startDate");

-- CreateIndex
CREATE INDEX "EventRegistration_eventId_idx" ON "EventRegistration"("eventId");

-- CreateIndex
CREATE INDEX "EventRegistration_userId_idx" ON "EventRegistration"("userId");

-- CreateIndex
CREATE UNIQUE INDEX "EventRegistration_eventId_userId_key" ON "EventRegistration"("eventId", "userId");

-- CreateIndex
CREATE INDEX "LiveService_status_scheduledAt_idx" ON "LiveService"("status", "scheduledAt");

-- CreateIndex
CREATE INDEX "LiveService_scheduledAt_idx" ON "LiveService"("scheduledAt");

-- CreateIndex
CREATE INDEX "PrayerRequest_liveServiceId_createdAt_idx" ON "PrayerRequest"("liveServiceId", "createdAt");

-- CreateIndex
CREATE INDEX "PrayerRequest_isRead_idx" ON "PrayerRequest"("isRead");

-- AddForeignKey
ALTER TABLE "GivingTransaction" ADD CONSTRAINT "GivingTransaction_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "GivingTransaction" ADD CONSTRAINT "GivingTransaction_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "GivingCategory"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "GivingPartner" ADD CONSTRAINT "GivingPartner_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "UpcomingEvent" ADD CONSTRAINT "UpcomingEvent_bannerFileId_fkey" FOREIGN KEY ("bannerFileId") REFERENCES "File"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "UpcomingEvent" ADD CONSTRAINT "UpcomingEvent_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EventRegistration" ADD CONSTRAINT "EventRegistration_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "UpcomingEvent"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "EventRegistration" ADD CONSTRAINT "EventRegistration_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "LiveService" ADD CONSTRAINT "LiveService_thumbnailFileId_fkey" FOREIGN KEY ("thumbnailFileId") REFERENCES "File"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "LiveService" ADD CONSTRAINT "LiveService_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PrayerRequest" ADD CONSTRAINT "PrayerRequest_liveServiceId_fkey" FOREIGN KEY ("liveServiceId") REFERENCES "LiveService"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PrayerRequest" ADD CONSTRAINT "PrayerRequest_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
