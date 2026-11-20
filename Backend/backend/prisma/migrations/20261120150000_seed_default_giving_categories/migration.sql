-- Give the public checkout usable defaults even when deployment runs
-- migrations without separately running the application seed.
INSERT INTO "GivingCategory" ("id", "name", "type", "sortOrder", "isActive", "createdAt", "updatedAt")
VALUES
  (gen_random_uuid(), 'General Offering', 'GENERAL_OFFERING', 0, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'Tithe', 'TITHE', 1, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'Ministry Partnership', 'MINISTRY_PARTNERSHIP', 2, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'Special Seed', 'SPECIAL_SEED', 3, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'Ministry Projects', 'MINISTRY_PROJECT', 4, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'Thanksgiving Offering', 'THANKSGIVING', 5, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'Other Donations', 'OTHER', 6, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT ("name") DO NOTHING;
