-- Clean up any partial or previous tables
DROP TABLE IF EXISTS "DailyDevotionCompletion" CASCADE;
DROP TABLE IF EXISTS "DailyDevotion" CASCADE;
DROP TABLE IF EXISTS "ShapeSpaceMessage" CASCADE;
DROP TABLE IF EXISTS "ShapeSpaceConversation" CASCADE;

CREATE TABLE "ShapeSpaceConversation" (
    "id" UUID NOT NULL,
    "memberId" UUID NOT NULL,
    "status" VARCHAR(20) NOT NULL DEFAULT 'OPEN',
    "isAnonymous" BOOLEAN NOT NULL DEFAULT false,
    "lastMessageAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "ShapeSpaceConversation_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "ShapeSpaceConversation_memberId_key" ON "ShapeSpaceConversation"("memberId");
CREATE INDEX "ShapeSpaceConversation_lastMessageAt_idx" ON "ShapeSpaceConversation"("lastMessageAt");
CREATE INDEX "ShapeSpaceConversation_status_idx" ON "ShapeSpaceConversation"("status");

ALTER TABLE "ShapeSpaceConversation" ADD CONSTRAINT "ShapeSpaceConversation_memberId_fkey"
  FOREIGN KEY ("memberId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "ShapeSpaceMessage" (
    "id" UUID NOT NULL,
    "conversationId" UUID NOT NULL,
    "senderId" UUID NOT NULL,
    "body" VARCHAR(2000) NOT NULL,
    "isAnonymous" BOOLEAN NOT NULL DEFAULT false,
    "isFromAdmin" BOOLEAN NOT NULL DEFAULT false,
    "readAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "hiddenAt" TIMESTAMP(3),
    CONSTRAINT "ShapeSpaceMessage_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "ShapeSpaceMessage_conversationId_createdAt_idx" ON "ShapeSpaceMessage"("conversationId", "createdAt");
CREATE INDEX "ShapeSpaceMessage_senderId_createdAt_idx" ON "ShapeSpaceMessage"("senderId", "createdAt");
CREATE INDEX "ShapeSpaceMessage_createdAt_idx" ON "ShapeSpaceMessage"("createdAt");

ALTER TABLE "ShapeSpaceMessage" ADD CONSTRAINT "ShapeSpaceMessage_conversationId_fkey"
  FOREIGN KEY ("conversationId") REFERENCES "ShapeSpaceConversation"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ShapeSpaceMessage" ADD CONSTRAINT "ShapeSpaceMessage_senderId_fkey"
  FOREIGN KEY ("senderId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "DailyDevotion" (
    "id" UUID NOT NULL,
    "dayOfYear" INTEGER NOT NULL,
    "month" INTEGER NOT NULL,
    "day" INTEGER NOT NULL,
    "date" DATE,
    "title" VARCHAR(255) NOT NULL,
    "anchorScripture" VARCHAR(255) NOT NULL,
    "scriptureReading" VARCHAR(255),
    "scriptureText" TEXT,
    "content" TEXT NOT NULL,
    "confession" TEXT,
    "prayer" TEXT,
    "oneYearBibleReading" VARCHAR(255),
    "thoughtForTheDay" TEXT,
    "author" VARCHAR(255) DEFAULT 'Pastor Healings E. Azuike',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "DailyDevotion_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "DailyDevotion_dayOfYear_key" ON "DailyDevotion"("dayOfYear");
CREATE INDEX "DailyDevotion_month_day_idx" ON "DailyDevotion"("month", "day");
CREATE INDEX "DailyDevotion_dayOfYear_idx" ON "DailyDevotion"("dayOfYear");

CREATE TABLE "DailyDevotionCompletion" (
    "id" UUID NOT NULL,
    "devotionId" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "completedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "isBookmarked" BOOLEAN NOT NULL DEFAULT false,
    "reflectionNotes" TEXT,
    CONSTRAINT "DailyDevotionCompletion_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "DailyDevotionCompletion_devotionId_userId_key" ON "DailyDevotionCompletion"("devotionId", "userId");
CREATE INDEX "DailyDevotionCompletion_userId_completedAt_idx" ON "DailyDevotionCompletion"("userId", "completedAt");

ALTER TABLE "DailyDevotionCompletion" ADD CONSTRAINT "DailyDevotionCompletion_devotionId_fkey"
  FOREIGN KEY ("devotionId") REFERENCES "DailyDevotion"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "DailyDevotionCompletion" ADD CONSTRAINT "DailyDevotionCompletion_userId_fkey"
  FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
