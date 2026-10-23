-- AlterTable
ALTER TABLE "DailyDietCompletion" ADD COLUMN     "attachmentFileId" UUID;

-- AddForeignKey
ALTER TABLE "DailyDietCompletion" ADD CONSTRAINT "DailyDietCompletion_attachmentFileId_fkey" FOREIGN KEY ("attachmentFileId") REFERENCES "File"("id") ON DELETE SET NULL ON UPDATE CASCADE;
