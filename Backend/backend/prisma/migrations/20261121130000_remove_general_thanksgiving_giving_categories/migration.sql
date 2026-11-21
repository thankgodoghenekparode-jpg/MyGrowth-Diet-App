-- Keep historical donation records intact while removing these options from
-- the public giving form, which lists active categories only.
UPDATE "GivingCategory"
SET "isActive" = false,
    "updatedAt" = CURRENT_TIMESTAMP
WHERE "name" IN ('General Offering', 'Thanksgiving Offering');
