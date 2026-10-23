-- CreateEnum
CREATE TYPE "Role" AS ENUM ('MAIN_ADMIN', 'ADMIN', 'MEMBER');

-- CreateEnum
CREATE TYPE "UserStatus" AS ENUM ('PENDING', 'ACTIVE', 'SUSPENDED', 'DEACTIVATED');

-- CreateEnum
CREATE TYPE "AdminAccess" AS ENUM ('NONE', 'PENDING', 'ACTIVE', 'SUSPENDED', 'REVOKED');

-- CreateEnum
CREATE TYPE "ContentStatus" AS ENUM ('DRAFT', 'PUBLISHED', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "ActivityCategory" AS ENUM ('prayer', 'scripture_reading', 'bible_study', 'literature_reading', 'proverbs_reading', 'fasting_and_prayer', 'prayer_and_affirmations', 'confessions_declarations', 'audio_message', 'prayer_partner_session', 'personal_reflection', 'custom');

-- CreateEnum
CREATE TYPE "ActivityRecordStatus" AS ENUM ('NOT_STARTED', 'IN_PROGRESS', 'COMPLETED', 'SKIPPED', 'NOT_APPLICABLE');

-- CreateEnum
CREATE TYPE "ActivityRecordSource" AS ENUM ('PLAN', 'CUSTOM');

-- CreateEnum
CREATE TYPE "GoalPeriodType" AS ENUM ('WEEKLY', 'MONTHLY');

-- CreateEnum
CREATE TYPE "GoalStatus" AS ENUM ('ACTIVE', 'COMPLETED', 'PAUSED', 'ABANDONED');

-- CreateEnum
CREATE TYPE "ReviewOutcome" AS ENUM ('COMPLETED', 'PARTIAL', 'NOT_COMPLETED');

-- CreateEnum
CREATE TYPE "PrayerAvailabilityStatus" AS ENUM ('AVAILABLE', 'UNAVAILABLE', 'TEMPORARILY_UNAVAILABLE');

-- CreateEnum
CREATE TYPE "PartnerRequestStatus" AS ENUM ('PENDING', 'ACCEPTED', 'DECLINED', 'CANCELLED', 'BLOCKED', 'REPORTED');

-- CreateEnum
CREATE TYPE "PartnershipStatus" AS ENUM ('ACTIVE', 'PAUSED', 'ENDED', 'BLOCKED');

-- CreateEnum
CREATE TYPE "SessionStatus" AS ENUM ('PROPOSED', 'ACCEPTED', 'COMPLETED', 'RESCHEDULED', 'CANCELLED', 'MISSED');

-- CreateEnum
CREATE TYPE "ReportType" AS ENUM ('WEEKLY', 'MONTHLY', 'QUARTERLY', 'ANNUAL');

-- CreateEnum
CREATE TYPE "ReportPeriodType" AS ENUM ('WEEK', 'MONTH', 'QUARTER', 'YEAR');

-- CreateEnum
CREATE TYPE "ReportStatus" AS ENUM ('DRAFT', 'SUBMITTED', 'REQUIRES_FOLLOW_UP', 'REVIEWED');

-- CreateEnum
CREATE TYPE "ReportReviewAction" AS ENUM ('COMMENT', 'REQUEST_FOLLOW_UP', 'MARK_REVIEWED');

-- CreateEnum
CREATE TYPE "TestimonyVisibility" AS ENUM ('PRIVATE', 'ADMINS', 'COMMUNITY');

-- CreateEnum
CREATE TYPE "TestimonyApproval" AS ENUM ('NOT_REQUESTED', 'PENDING', 'APPROVED', 'REJECTED');

-- CreateEnum
CREATE TYPE "MaterialCategory" AS ENUM ('PDF_DOCUMENT', 'AUDIO_MESSAGE', 'VIDEO', 'BIBLE_STUDY_NOTES', 'LITERATURE_REFERENCE', 'PRAYER_GUIDE', 'SCRIPTURE_READING_LINK', 'CONFESSION_DECLARATION', 'ANNOUNCEMENT', 'OTHER');

-- CreateEnum
CREATE TYPE "MaterialVisibility" AS ENUM ('ALL_MEMBERS', 'ADMINS_ONLY');

-- CreateEnum
CREATE TYPE "NotificationEventType" AS ENUM ('welcome_verification', 'membership_approved', 'programme_published', 'material_published', 'daily_activity_reminder', 'weekly_report_reminder', 'monthly_report_reminder', 'quarterly_review_reminder', 'annual_reflection_reminder', 'new_announcement', 'partner_request_received', 'partner_request_accepted', 'partner_request_declined', 'session_proposed', 'session_accepted', 'session_rescheduled', 'session_cancelled', 'session_upcoming', 'admin_report_comment', 'admin_report_follow_up');

-- CreateEnum
CREATE TYPE "NotificationChannel" AS ENUM ('IN_APP', 'EMAIL');

-- CreateEnum
CREATE TYPE "DeliveryStatus" AS ENUM ('NOT_NEEDED', 'QUEUED', 'SENT', 'FAILED');

-- CreateEnum
CREATE TYPE "Audience" AS ENUM ('ALL_MEMBERS', 'ADMINS_ONLY');

-- CreateEnum
CREATE TYPE "SafetyReportStatus" AS ENUM ('OPEN', 'REVIEWED', 'RESOLVED');

-- CreateEnum
CREATE TYPE "AuditOutcome" AS ENUM ('SUCCESS', 'DENIED');

-- CreateTable
CREATE TABLE "User" (
    "id" UUID NOT NULL,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "firstName" TEXT NOT NULL,
    "lastName" TEXT NOT NULL,
    "phone" TEXT,
    "role" "Role" NOT NULL DEFAULT 'MEMBER',
    "status" "UserStatus" NOT NULL DEFAULT 'ACTIVE',
    "adminAccess" "AdminAccess" NOT NULL DEFAULT 'NONE',
    "emailVerifiedAt" TIMESTAMP(3),
    "timezone" TEXT NOT NULL DEFAULT 'Africa/Lagos',
    "locale" TEXT NOT NULL DEFAULT 'en',
    "avatarFileId" UUID,
    "profileCompletedAt" TIMESTAMP(3),
    "lastLoginAt" TIMESTAMP(3),
    "verificationTokenHash" TEXT,
    "verificationTokenExpiresAt" TIMESTAMP(3),
    "passwordResetTokenHash" TEXT,
    "passwordResetExpiresAt" TIMESTAMP(3),
    "createdByAdminId" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "RefreshToken" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "tokenHash" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "revokedAt" TIMESTAMP(3),
    "replacedById" UUID,
    "userAgent" TEXT,
    "ipAddress" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "RefreshToken_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Programme" (
    "id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "year" INTEGER NOT NULL,
    "ministry" TEXT NOT NULL,
    "description" TEXT,
    "annualPrayerFocus" TEXT,
    "dailyAffirmation" TEXT,
    "startDate" DATE,
    "endDate" DATE,
    "status" "ContentStatus" NOT NULL DEFAULT 'DRAFT',
    "createdById" UUID,
    "updatedById" UUID,
    "publishedAt" TIMESTAMP(3),
    "archivedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Programme_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MonthlyPlan" (
    "id" UUID NOT NULL,
    "programmeId" UUID NOT NULL,
    "month" INTEGER NOT NULL,
    "year" INTEGER NOT NULL,
    "theme" TEXT,
    "prayerFocus" TEXT,
    "bibleReadingGuidance" TEXT,
    "literatureList" JSONB,
    "audioMessages" JSONB,
    "fastingGuidance" TEXT,
    "monthlyConfession" TEXT,
    "monthlyGoalsGuidance" TEXT,
    "reflectionQuestions" JSONB,
    "status" "ContentStatus" NOT NULL DEFAULT 'DRAFT',
    "publishedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "MonthlyPlan_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "WeeklyPlan" (
    "id" UUID NOT NULL,
    "programmeId" UUID NOT NULL,
    "monthlyPlanId" UUID,
    "weekNumber" INTEGER NOT NULL,
    "startDate" DATE,
    "endDate" DATE,
    "bibleReading" TEXT,
    "prayerDurationTargetMinutes" INTEGER,
    "bookReading" TEXT,
    "fastingSchedule" TEXT,
    "keyLessonPrompt" TEXT,
    "memoryVerse" TEXT,
    "studyMaterialIds" JSONB,
    "audioMaterialIds" JSONB,
    "extraActivities" JSONB,
    "status" "ContentStatus" NOT NULL DEFAULT 'DRAFT',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "WeeklyPlan_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "DailyActivity" (
    "id" UUID NOT NULL,
    "programmeId" UUID NOT NULL,
    "monthlyPlanId" UUID,
    "weeklyPlanId" UUID,
    "date" DATE,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "category" "ActivityCategory" NOT NULL,
    "startTime" TEXT,
    "durationMinutes" INTEGER,
    "quantityTarget" INTEGER,
    "quantityUnit" TEXT,
    "relatedMaterialId" UUID,
    "completionInstructions" TEXT,
    "trackCompletion" BOOLEAN NOT NULL DEFAULT true,
    "allowNote" BOOLEAN NOT NULL DEFAULT true,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "status" "ContentStatus" NOT NULL DEFAULT 'DRAFT',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "DailyActivity_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ActivityCategoryDef" (
    "id" UUID NOT NULL,
    "key" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "description" TEXT,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ActivityCategoryDef_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "NotificationEventDef" (
    "id" UUID NOT NULL,
    "key" TEXT NOT NULL,
    "label" TEXT NOT NULL,
    "description" TEXT,
    "defaultEnabled" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "NotificationEventDef_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "File" (
    "id" UUID NOT NULL,
    "originalName" TEXT NOT NULL,
    "mimeType" TEXT NOT NULL,
    "sizeBytes" INTEGER NOT NULL,
    "storageKey" TEXT NOT NULL,
    "storageAdapter" TEXT NOT NULL DEFAULT 'local',
    "uploadedById" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "File_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Material" (
    "id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "category" "MaterialCategory" NOT NULL,
    "programmeYear" INTEGER,
    "programmeId" UUID,
    "month" INTEGER,
    "week" INTEGER,
    "fileId" UUID,
    "thumbnailFileId" UUID,
    "externalUrl" TEXT,
    "authorSpeaker" TEXT,
    "publicationDate" DATE,
    "visibility" "MaterialVisibility" NOT NULL DEFAULT 'ALL_MEMBERS',
    "trackCompletion" BOOLEAN NOT NULL DEFAULT false,
    "status" "ContentStatus" NOT NULL DEFAULT 'DRAFT',
    "createdById" UUID,
    "updatedById" UUID,
    "publishedAt" TIMESTAMP(3),
    "archivedAt" TIMESTAMP(3),
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Material_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "MaterialCompletion" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "materialId" UUID NOT NULL,
    "completedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MaterialCompletion_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ReadingListEntry" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "materialId" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ReadingListEntry_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "UserActivityRecord" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "activityId" UUID,
    "category" "ActivityCategory" NOT NULL,
    "source" "ActivityRecordSource" NOT NULL DEFAULT 'PLAN',
    "date" DATE NOT NULL,
    "title" TEXT NOT NULL,
    "status" "ActivityRecordStatus" NOT NULL DEFAULT 'NOT_STARTED',
    "note" TEXT,
    "actualDurationMinutes" INTEGER,
    "actualQuantity" INTEGER,
    "completedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "UserActivityRecord_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PersonalGoal" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "programmeId" UUID,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "periodType" "GoalPeriodType" NOT NULL,
    "startDate" DATE NOT NULL,
    "targetDate" DATE NOT NULL,
    "targetQuantity" INTEGER,
    "unit" TEXT,
    "currentProgress" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "status" "GoalStatus" NOT NULL DEFAULT 'ACTIVE',
    "privateNotes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PersonalGoal_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "GoalProgressEntry" (
    "id" UUID NOT NULL,
    "goalId" UUID NOT NULL,
    "value" DOUBLE PRECISION NOT NULL,
    "note" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "GoalProgressEntry_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ProgressReview" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "periodType" "GoalPeriodType" NOT NULL,
    "periodKey" TEXT NOT NULL,
    "outcome" "ReviewOutcome" NOT NULL,
    "lessonsLearned" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ProgressReview_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PrayerAvailability" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "availability" "PrayerAvailabilityStatus" NOT NULL DEFAULT 'UNAVAILABLE',
    "availableDays" JSONB,
    "preferredTimeRanges" JSONB,
    "timezone" TEXT NOT NULL DEFAULT 'Africa/Lagos',
    "preferredDurationMinutes" INTEGER NOT NULL DEFAULT 30,
    "preferredLanguage" TEXT NOT NULL DEFAULT 'English',
    "acceptsNewRequests" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PrayerAvailability_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PrayerPartnerRequest" (
    "id" UUID NOT NULL,
    "requesterId" UUID NOT NULL,
    "recipientId" UUID NOT NULL,
    "message" TEXT,
    "status" "PartnerRequestStatus" NOT NULL DEFAULT 'PENDING',
    "respondedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PrayerPartnerRequest_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PrayerPartnership" (
    "id" UUID NOT NULL,
    "userAId" UUID NOT NULL,
    "userBId" UUID NOT NULL,
    "status" "PartnershipStatus" NOT NULL DEFAULT 'ACTIVE',
    "initiatedById" UUID,
    "startedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "pausedAt" TIMESTAMP(3),
    "endedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PrayerPartnership_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PrayerSession" (
    "id" UUID NOT NULL,
    "partnershipId" UUID NOT NULL,
    "proposedById" UUID NOT NULL,
    "acceptedById" UUID,
    "date" DATE NOT NULL,
    "startTime" TEXT NOT NULL,
    "durationMinutes" INTEGER NOT NULL DEFAULT 30,
    "timezone" TEXT NOT NULL DEFAULT 'Africa/Lagos',
    "prayerFocus" TEXT,
    "meetingMethod" TEXT,
    "meetingLink" TEXT,
    "status" "SessionStatus" NOT NULL DEFAULT 'PROPOSED',
    "acceptedAt" TIMESTAMP(3),
    "completedAt" TIMESTAMP(3),
    "proposerNote" TEXT,
    "partnerNote" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PrayerSession_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "PrayerBlock" (
    "id" UUID NOT NULL,
    "blockerId" UUID NOT NULL,
    "blockedId" UUID NOT NULL,
    "reason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "PrayerBlock_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "SafetyReport" (
    "id" UUID NOT NULL,
    "reporterId" UUID NOT NULL,
    "reportedId" UUID NOT NULL,
    "partnershipId" UUID,
    "reason" TEXT NOT NULL,
    "details" TEXT,
    "status" "SafetyReportStatus" NOT NULL DEFAULT 'OPEN',
    "resolvedById" UUID,
    "resolutionNote" TEXT,
    "resolvedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "SafetyReport_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Report" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "programmeId" UUID,
    "periodType" "ReportPeriodType" NOT NULL,
    "periodKey" TEXT NOT NULL,
    "reportType" "ReportType" NOT NULL,
    "status" "ReportStatus" NOT NULL DEFAULT 'DRAFT',
    "visibilityNotice" TEXT,
    "revision" INTEGER NOT NULL DEFAULT 1,
    "submittedAt" TIMESTAMP(3),
    "reviewedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Report_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ReportAnswer" (
    "id" UUID NOT NULL,
    "reportId" UUID NOT NULL,
    "fieldKey" TEXT NOT NULL,
    "value" TEXT NOT NULL,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ReportAnswer_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ReportRevision" (
    "id" UUID NOT NULL,
    "reportId" UUID NOT NULL,
    "revisionNumber" INTEGER NOT NULL,
    "snapshot" JSONB NOT NULL,
    "reason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ReportRevision_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ReportReview" (
    "id" UUID NOT NULL,
    "reportId" UUID NOT NULL,
    "reviewerId" UUID NOT NULL,
    "action" "ReportReviewAction" NOT NULL,
    "comment" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ReportReview_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ReflectionEntry" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "entryDate" DATE NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ReflectionEntry_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AnnualLetter" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "programmeId" UUID NOT NULL,
    "body" TEXT NOT NULL DEFAULT '',
    "isDraft" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AnnualLetter_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Testimony" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "entryDate" DATE NOT NULL,
    "story" TEXT NOT NULL,
    "tags" JSONB,
    "visibility" "TestimonyVisibility" NOT NULL DEFAULT 'PRIVATE',
    "consentToShare" BOOLEAN NOT NULL DEFAULT false,
    "approvalStatus" "TestimonyApproval" NOT NULL DEFAULT 'NOT_REQUESTED',
    "publishedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Testimony_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Notification" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "eventType" "NotificationEventType" NOT NULL,
    "eventKey" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT,
    "data" JSONB,
    "channel" "NotificationChannel" NOT NULL DEFAULT 'IN_APP',
    "deliveryStatus" "DeliveryStatus" NOT NULL DEFAULT 'NOT_NEEDED',
    "deliveryError" TEXT,
    "readAt" TIMESTAMP(3),
    "emailSentAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Notification_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "NotificationPreference" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "emailEnabled" BOOLEAN NOT NULL DEFAULT true,
    "inAppEnabled" BOOLEAN NOT NULL DEFAULT true,
    "dailyReminderEnabled" BOOLEAN NOT NULL DEFAULT true,
    "dailyReminderTime" TEXT NOT NULL DEFAULT '06:00',
    "weeklyReminderEnabled" BOOLEAN NOT NULL DEFAULT true,
    "monthlyReminderEnabled" BOOLEAN NOT NULL DEFAULT true,
    "quarterlyReminderEnabled" BOOLEAN NOT NULL DEFAULT true,
    "annualReminderEnabled" BOOLEAN NOT NULL DEFAULT true,
    "sessionReminderMinutes" INTEGER NOT NULL DEFAULT 30,
    "summaryPreference" TEXT NOT NULL DEFAULT 'daily',
    "quietHoursStart" TEXT,
    "quietHoursEnd" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "NotificationPreference_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Announcement" (
    "id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "body" TEXT NOT NULL,
    "link" TEXT,
    "materialId" UUID,
    "audience" "Audience" NOT NULL DEFAULT 'ALL_MEMBERS',
    "startsAt" TIMESTAMP(3),
    "endsAt" TIMESTAMP(3),
    "status" "ContentStatus" NOT NULL DEFAULT 'DRAFT',
    "createdById" UUID,
    "publishedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Announcement_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Setting" (
    "key" TEXT NOT NULL,
    "value" JSONB NOT NULL,
    "updatedBy" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Setting_pkey" PRIMARY KEY ("key")
);

-- CreateTable
CREATE TABLE "AuditLog" (
    "id" UUID NOT NULL,
    "actorId" UUID,
    "actorRole" TEXT,
    "actorEmail" TEXT,
    "targetType" TEXT NOT NULL,
    "targetId" TEXT,
    "action" TEXT NOT NULL,
    "outcome" "AuditOutcome" NOT NULL DEFAULT 'SUCCESS',
    "details" JSONB,
    "ipAddress" TEXT,
    "userAgent" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AuditLog_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE INDEX "User_role_idx" ON "User"("role");

-- CreateIndex
CREATE INDEX "User_status_idx" ON "User"("status");

-- CreateIndex
CREATE INDEX "User_createdAt_idx" ON "User"("createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "RefreshToken_tokenHash_key" ON "RefreshToken"("tokenHash");

-- CreateIndex
CREATE INDEX "RefreshToken_userId_idx" ON "RefreshToken"("userId");

-- CreateIndex
CREATE INDEX "RefreshToken_expiresAt_idx" ON "RefreshToken"("expiresAt");

-- CreateIndex
CREATE INDEX "Programme_year_idx" ON "Programme"("year");

-- CreateIndex
CREATE INDEX "Programme_status_idx" ON "Programme"("status");

-- CreateIndex
CREATE INDEX "MonthlyPlan_year_month_idx" ON "MonthlyPlan"("year", "month");

-- CreateIndex
CREATE INDEX "MonthlyPlan_status_idx" ON "MonthlyPlan"("status");

-- CreateIndex
CREATE UNIQUE INDEX "MonthlyPlan_programmeId_month_key" ON "MonthlyPlan"("programmeId", "month");

-- CreateIndex
CREATE INDEX "WeeklyPlan_startDate_idx" ON "WeeklyPlan"("startDate");

-- CreateIndex
CREATE INDEX "WeeklyPlan_status_idx" ON "WeeklyPlan"("status");

-- CreateIndex
CREATE UNIQUE INDEX "WeeklyPlan_programmeId_monthlyPlanId_weekNumber_key" ON "WeeklyPlan"("programmeId", "monthlyPlanId", "weekNumber");

-- CreateIndex
CREATE INDEX "DailyActivity_programmeId_date_idx" ON "DailyActivity"("programmeId", "date");

-- CreateIndex
CREATE INDEX "DailyActivity_monthlyPlanId_idx" ON "DailyActivity"("monthlyPlanId");

-- CreateIndex
CREATE INDEX "DailyActivity_weeklyPlanId_idx" ON "DailyActivity"("weeklyPlanId");

-- CreateIndex
CREATE INDEX "DailyActivity_status_idx" ON "DailyActivity"("status");

-- CreateIndex
CREATE UNIQUE INDEX "ActivityCategoryDef_key_key" ON "ActivityCategoryDef"("key");

-- CreateIndex
CREATE UNIQUE INDEX "NotificationEventDef_key_key" ON "NotificationEventDef"("key");

-- CreateIndex
CREATE INDEX "File_uploadedById_idx" ON "File"("uploadedById");

-- CreateIndex
CREATE INDEX "File_createdAt_idx" ON "File"("createdAt");

-- CreateIndex
CREATE INDEX "Material_status_idx" ON "Material"("status");

-- CreateIndex
CREATE INDEX "Material_programmeYear_idx" ON "Material"("programmeYear");

-- CreateIndex
CREATE INDEX "Material_category_idx" ON "Material"("category");

-- CreateIndex
CREATE INDEX "Material_createdAt_idx" ON "Material"("createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "MaterialCompletion_userId_materialId_key" ON "MaterialCompletion"("userId", "materialId");

-- CreateIndex
CREATE UNIQUE INDEX "ReadingListEntry_userId_materialId_key" ON "ReadingListEntry"("userId", "materialId");

-- CreateIndex
CREATE INDEX "UserActivityRecord_userId_date_idx" ON "UserActivityRecord"("userId", "date");

-- CreateIndex
CREATE INDEX "UserActivityRecord_userId_idx" ON "UserActivityRecord"("userId");

-- CreateIndex
CREATE INDEX "UserActivityRecord_category_idx" ON "UserActivityRecord"("category");

-- CreateIndex
CREATE INDEX "PersonalGoal_userId_idx" ON "PersonalGoal"("userId");

-- CreateIndex
CREATE INDEX "PersonalGoal_periodType_status_idx" ON "PersonalGoal"("periodType", "status");

-- CreateIndex
CREATE INDEX "GoalProgressEntry_goalId_idx" ON "GoalProgressEntry"("goalId");

-- CreateIndex
CREATE UNIQUE INDEX "ProgressReview_userId_periodType_periodKey_key" ON "ProgressReview"("userId", "periodType", "periodKey");

-- CreateIndex
CREATE UNIQUE INDEX "PrayerAvailability_userId_key" ON "PrayerAvailability"("userId");

-- CreateIndex
CREATE INDEX "PrayerPartnerRequest_recipientId_status_idx" ON "PrayerPartnerRequest"("recipientId", "status");

-- CreateIndex
CREATE INDEX "PrayerPartnerRequest_requesterId_status_idx" ON "PrayerPartnerRequest"("requesterId", "status");

-- CreateIndex
CREATE INDEX "PrayerPartnerRequest_createdAt_idx" ON "PrayerPartnerRequest"("createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "PrayerPartnerRequest_requesterId_recipientId_status_key" ON "PrayerPartnerRequest"("requesterId", "recipientId", "status");

-- CreateIndex
CREATE INDEX "PrayerPartnership_status_idx" ON "PrayerPartnership"("status");

-- CreateIndex
CREATE UNIQUE INDEX "PrayerPartnership_userAId_userBId_key" ON "PrayerPartnership"("userAId", "userBId");

-- CreateIndex
CREATE INDEX "PrayerSession_partnershipId_status_idx" ON "PrayerSession"("partnershipId", "status");

-- CreateIndex
CREATE INDEX "PrayerSession_date_idx" ON "PrayerSession"("date");

-- CreateIndex
CREATE INDEX "PrayerSession_status_idx" ON "PrayerSession"("status");

-- CreateIndex
CREATE UNIQUE INDEX "PrayerBlock_blockerId_blockedId_key" ON "PrayerBlock"("blockerId", "blockedId");

-- CreateIndex
CREATE INDEX "SafetyReport_status_idx" ON "SafetyReport"("status");

-- CreateIndex
CREATE INDEX "SafetyReport_createdAt_idx" ON "SafetyReport"("createdAt");

-- CreateIndex
CREATE INDEX "Report_userId_idx" ON "Report"("userId");

-- CreateIndex
CREATE INDEX "Report_status_idx" ON "Report"("status");

-- CreateIndex
CREATE INDEX "Report_periodType_periodKey_idx" ON "Report"("periodType", "periodKey");

-- CreateIndex
CREATE INDEX "Report_programmeId_idx" ON "Report"("programmeId");

-- CreateIndex
CREATE UNIQUE INDEX "Report_userId_periodType_periodKey_reportType_key" ON "Report"("userId", "periodType", "periodKey", "reportType");

-- CreateIndex
CREATE UNIQUE INDEX "ReportAnswer_reportId_fieldKey_key" ON "ReportAnswer"("reportId", "fieldKey");

-- CreateIndex
CREATE UNIQUE INDEX "ReportRevision_reportId_revisionNumber_key" ON "ReportRevision"("reportId", "revisionNumber");

-- CreateIndex
CREATE INDEX "ReportReview_reportId_idx" ON "ReportReview"("reportId");

-- CreateIndex
CREATE INDEX "ReportReview_reviewerId_idx" ON "ReportReview"("reviewerId");

-- CreateIndex
CREATE INDEX "ReportReview_createdAt_idx" ON "ReportReview"("createdAt");

-- CreateIndex
CREATE INDEX "ReflectionEntry_userId_entryDate_idx" ON "ReflectionEntry"("userId", "entryDate");

-- CreateIndex
CREATE UNIQUE INDEX "AnnualLetter_userId_programmeId_key" ON "AnnualLetter"("userId", "programmeId");

-- CreateIndex
CREATE INDEX "Testimony_userId_idx" ON "Testimony"("userId");

-- CreateIndex
CREATE INDEX "Testimony_visibility_approvalStatus_idx" ON "Testimony"("visibility", "approvalStatus");

-- CreateIndex
CREATE INDEX "Notification_userId_readAt_idx" ON "Notification"("userId", "readAt");

-- CreateIndex
CREATE INDEX "Notification_userId_createdAt_idx" ON "Notification"("userId", "createdAt");

-- CreateIndex
CREATE UNIQUE INDEX "Notification_userId_eventType_eventKey_key" ON "Notification"("userId", "eventType", "eventKey");

-- CreateIndex
CREATE UNIQUE INDEX "NotificationPreference_userId_key" ON "NotificationPreference"("userId");

-- CreateIndex
CREATE INDEX "Announcement_status_startsAt_endsAt_idx" ON "Announcement"("status", "startsAt", "endsAt");

-- CreateIndex
CREATE INDEX "AuditLog_createdAt_idx" ON "AuditLog"("createdAt");

-- CreateIndex
CREATE INDEX "AuditLog_actorId_idx" ON "AuditLog"("actorId");

-- CreateIndex
CREATE INDEX "AuditLog_targetType_targetId_idx" ON "AuditLog"("targetType", "targetId");

-- CreateIndex
CREATE INDEX "AuditLog_action_idx" ON "AuditLog"("action");

-- AddForeignKey
ALTER TABLE "User" ADD CONSTRAINT "User_avatarFileId_fkey" FOREIGN KEY ("avatarFileId") REFERENCES "File"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "User" ADD CONSTRAINT "User_createdByAdminId_fkey" FOREIGN KEY ("createdByAdminId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RefreshToken" ADD CONSTRAINT "RefreshToken_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Programme" ADD CONSTRAINT "Programme_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Programme" ADD CONSTRAINT "Programme_updatedById_fkey" FOREIGN KEY ("updatedById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MonthlyPlan" ADD CONSTRAINT "MonthlyPlan_programmeId_fkey" FOREIGN KEY ("programmeId") REFERENCES "Programme"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WeeklyPlan" ADD CONSTRAINT "WeeklyPlan_programmeId_fkey" FOREIGN KEY ("programmeId") REFERENCES "Programme"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WeeklyPlan" ADD CONSTRAINT "WeeklyPlan_monthlyPlanId_fkey" FOREIGN KEY ("monthlyPlanId") REFERENCES "MonthlyPlan"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DailyActivity" ADD CONSTRAINT "DailyActivity_programmeId_fkey" FOREIGN KEY ("programmeId") REFERENCES "Programme"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DailyActivity" ADD CONSTRAINT "DailyActivity_monthlyPlanId_fkey" FOREIGN KEY ("monthlyPlanId") REFERENCES "MonthlyPlan"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DailyActivity" ADD CONSTRAINT "DailyActivity_weeklyPlanId_fkey" FOREIGN KEY ("weeklyPlanId") REFERENCES "WeeklyPlan"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "DailyActivity" ADD CONSTRAINT "DailyActivity_relatedMaterialId_fkey" FOREIGN KEY ("relatedMaterialId") REFERENCES "Material"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "File" ADD CONSTRAINT "File_uploadedById_fkey" FOREIGN KEY ("uploadedById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Material" ADD CONSTRAINT "Material_programmeId_fkey" FOREIGN KEY ("programmeId") REFERENCES "Programme"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Material" ADD CONSTRAINT "Material_fileId_fkey" FOREIGN KEY ("fileId") REFERENCES "File"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Material" ADD CONSTRAINT "Material_thumbnailFileId_fkey" FOREIGN KEY ("thumbnailFileId") REFERENCES "File"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Material" ADD CONSTRAINT "Material_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Material" ADD CONSTRAINT "Material_updatedById_fkey" FOREIGN KEY ("updatedById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MaterialCompletion" ADD CONSTRAINT "MaterialCompletion_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MaterialCompletion" ADD CONSTRAINT "MaterialCompletion_materialId_fkey" FOREIGN KEY ("materialId") REFERENCES "Material"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReadingListEntry" ADD CONSTRAINT "ReadingListEntry_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReadingListEntry" ADD CONSTRAINT "ReadingListEntry_materialId_fkey" FOREIGN KEY ("materialId") REFERENCES "Material"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "UserActivityRecord" ADD CONSTRAINT "UserActivityRecord_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "UserActivityRecord" ADD CONSTRAINT "UserActivityRecord_activityId_fkey" FOREIGN KEY ("activityId") REFERENCES "DailyActivity"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PersonalGoal" ADD CONSTRAINT "PersonalGoal_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PersonalGoal" ADD CONSTRAINT "PersonalGoal_programmeId_fkey" FOREIGN KEY ("programmeId") REFERENCES "Programme"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "GoalProgressEntry" ADD CONSTRAINT "GoalProgressEntry_goalId_fkey" FOREIGN KEY ("goalId") REFERENCES "PersonalGoal"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ProgressReview" ADD CONSTRAINT "ProgressReview_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PrayerAvailability" ADD CONSTRAINT "PrayerAvailability_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PrayerPartnerRequest" ADD CONSTRAINT "PrayerPartnerRequest_requesterId_fkey" FOREIGN KEY ("requesterId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PrayerPartnerRequest" ADD CONSTRAINT "PrayerPartnerRequest_recipientId_fkey" FOREIGN KEY ("recipientId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PrayerPartnership" ADD CONSTRAINT "PrayerPartnership_userAId_fkey" FOREIGN KEY ("userAId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PrayerPartnership" ADD CONSTRAINT "PrayerPartnership_userBId_fkey" FOREIGN KEY ("userBId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PrayerSession" ADD CONSTRAINT "PrayerSession_partnershipId_fkey" FOREIGN KEY ("partnershipId") REFERENCES "PrayerPartnership"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PrayerSession" ADD CONSTRAINT "PrayerSession_proposedById_fkey" FOREIGN KEY ("proposedById") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PrayerSession" ADD CONSTRAINT "PrayerSession_acceptedById_fkey" FOREIGN KEY ("acceptedById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PrayerBlock" ADD CONSTRAINT "PrayerBlock_blockerId_fkey" FOREIGN KEY ("blockerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PrayerBlock" ADD CONSTRAINT "PrayerBlock_blockedId_fkey" FOREIGN KEY ("blockedId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SafetyReport" ADD CONSTRAINT "SafetyReport_reporterId_fkey" FOREIGN KEY ("reporterId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SafetyReport" ADD CONSTRAINT "SafetyReport_reportedId_fkey" FOREIGN KEY ("reportedId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Report" ADD CONSTRAINT "Report_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Report" ADD CONSTRAINT "Report_programmeId_fkey" FOREIGN KEY ("programmeId") REFERENCES "Programme"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReportAnswer" ADD CONSTRAINT "ReportAnswer_reportId_fkey" FOREIGN KEY ("reportId") REFERENCES "Report"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReportRevision" ADD CONSTRAINT "ReportRevision_reportId_fkey" FOREIGN KEY ("reportId") REFERENCES "Report"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReportReview" ADD CONSTRAINT "ReportReview_reportId_fkey" FOREIGN KEY ("reportId") REFERENCES "Report"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReportReview" ADD CONSTRAINT "ReportReview_reviewerId_fkey" FOREIGN KEY ("reviewerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ReflectionEntry" ADD CONSTRAINT "ReflectionEntry_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AnnualLetter" ADD CONSTRAINT "AnnualLetter_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AnnualLetter" ADD CONSTRAINT "AnnualLetter_programmeId_fkey" FOREIGN KEY ("programmeId") REFERENCES "Programme"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Testimony" ADD CONSTRAINT "Testimony_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Notification" ADD CONSTRAINT "Notification_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "NotificationPreference" ADD CONSTRAINT "NotificationPreference_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Announcement" ADD CONSTRAINT "Announcement_materialId_fkey" FOREIGN KEY ("materialId") REFERENCES "Material"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Announcement" ADD CONSTRAINT "Announcement_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AuditLog" ADD CONSTRAINT "AuditLog_actorId_fkey" FOREIGN KEY ("actorId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
