CREATE TYPE "GivingFrequency" AS ENUM ('WEEKLY', 'MONTHLY', 'YEARLY');

CREATE TABLE "MinistryPartnership" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "currency" VARCHAR(3) NOT NULL DEFAULT 'NGN',
    "frequency" "GivingFrequency" NOT NULL,
    "status" "PartnershipStatus" NOT NULL DEFAULT 'ACTIVE',
    "note" VARCHAR(500),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "MinistryPartnership_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "MinistryPartnership_userId_key" ON "MinistryPartnership"("userId");
CREATE INDEX "MinistryPartnership_status_frequency_idx" ON "MinistryPartnership"("status", "frequency");
CREATE INDEX "MinistryPartnership_createdAt_idx" ON "MinistryPartnership"("createdAt");

ALTER TABLE "MinistryPartnership" ADD CONSTRAINT "MinistryPartnership_userId_fkey"
  FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
