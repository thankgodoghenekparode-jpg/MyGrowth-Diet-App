CREATE TABLE "ShapeSpaceMessage" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "body" VARCHAR(1000) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "hiddenAt" TIMESTAMP(3),
    CONSTRAINT "ShapeSpaceMessage_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "ShapeSpaceMessage_createdAt_idx" ON "ShapeSpaceMessage"("createdAt");
CREATE INDEX "ShapeSpaceMessage_userId_createdAt_idx" ON "ShapeSpaceMessage"("userId", "createdAt");
ALTER TABLE "ShapeSpaceMessage" ADD CONSTRAINT "ShapeSpaceMessage_userId_fkey"
  FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
