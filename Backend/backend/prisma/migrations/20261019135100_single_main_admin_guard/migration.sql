-- Enforce the single-Main-Admin invariant at the database layer.
-- A trigger (rather than a partial unique index) is used because it can raise
-- a clear error and take a transaction-scoped advisory lock, so concurrent
-- attempts cannot both succeed.

CREATE OR REPLACE FUNCTION enforce_single_main_admin() RETURNS trigger AS $$
BEGIN
  IF NEW."role" = 'MAIN_ADMIN' THEN
    -- Serialize concurrent inserts/updates that would create a Main Admin.
    PERFORM pg_advisory_xact_lock(918273645);
    IF EXISTS (
      SELECT 1 FROM "User"
      WHERE "role" = 'MAIN_ADMIN' AND "id" <> NEW."id"
    ) THEN
      RAISE EXCEPTION 'Only one MAIN_ADMIN account may exist'
        USING ERRCODE = 'unique_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS "User_single_main_admin" ON "User";
CREATE TRIGGER "User_single_main_admin"
  BEFORE INSERT OR UPDATE OF "role" ON "User"
  FOR EACH ROW EXECUTE FUNCTION enforce_single_main_admin();
