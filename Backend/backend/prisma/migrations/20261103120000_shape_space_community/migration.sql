-- Existing Shape Space threads were private counseling conversations.
-- Keep those private while allowing each member to create multiple public Q&A threads.
ALTER TABLE "ShapeSpaceConversation"
  ADD COLUMN "isCommunity" BOOLEAN NOT NULL DEFAULT false;

DROP INDEX IF EXISTS "ShapeSpaceConversation_memberId_key";

CREATE INDEX "ShapeSpaceConversation_isCommunity_lastMessageAt_idx"
  ON "ShapeSpaceConversation"("isCommunity", "lastMessageAt");
