/**
 * Test database preparation.
 *
 * Applies all migrations to TEST_DATABASE_URL and truncates application tables
 * so `npm test` starts from a clean, fully-migrated database. Test files reset
 * the database again in their `before` hooks via tests/helpers/setup.js.
 *
 * The application under test uses TEST_DATABASE_URL when NODE_ENV=test (see
 * src/db/index.js), so production/development data is never touched.
 */
import 'dotenv/config';
import { execSync } from 'node:child_process';
import { PrismaClient } from '@prisma/client';

const testUrl = process.env.TEST_DATABASE_URL;

if (!testUrl) {
  console.error('[test-setup] TEST_DATABASE_URL is not set. Add it to .env before running tests.');
  process.exit(1);
}

if (/mygrowth_diet_plan\?/.test(testUrl) && !/test/.test(testUrl)) {
  console.error('[test-setup] Refusing to run: TEST_DATABASE_URL does not look like a test database.');
  process.exit(1);
}

console.log(`[test-setup] applying migrations to the test database...`);
execSync('npx prisma migrate deploy', {
  stdio: 'inherit',
  env: { ...process.env, DATABASE_URL: testUrl },
});

const prisma = new PrismaClient({
  datasources: { db: { url: testUrl } },
});

async function truncateAll() {
  const rows = await prisma.$queryRawUnsafe(
    `SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename <> '_prisma_migrations'`
  );
  const tables = rows.map((r) => `"public"."${r.tablename}"`);
  if (tables.length === 0) return;
  await prisma.$executeRawUnsafe(`TRUNCATE TABLE ${tables.join(', ')} RESTART IDENTITY CASCADE`);
  console.log(`[test-setup] truncated ${tables.length} tables`);
}

truncateAll()
  .catch((err) => {
    console.error('[test-setup] failed:', err);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
