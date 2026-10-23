/**
 * Test environment bootstrap.
 *
 * IMPORTANT: this module must be imported *before* any `src/**` module. ES module
 * imports are evaluated depth-first in source order, so a test file that starts
 * with `import '../helpers/setup.js'` (which itself imports this file first) is
 * guaranteed to run this code before `src/config/index.js` reads process.env.
 *
 * It forces NODE_ENV=test and points the application at TEST_DATABASE_URL so the
 * suite can never touch the development/production database.
 */
import 'dotenv/config';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

process.env.NODE_ENV = 'test';

// Keep test uploads out of the development storage directory, and make sure
// multer's destination exists before the first upload.
process.env.UPLOAD_DIR =
  process.env.TEST_UPLOAD_DIR ?? path.join(os.tmpdir(), 'mygrowth-diet-test-uploads');
fs.mkdirSync(process.env.UPLOAD_DIR, { recursive: true });

if (process.env.TEST_DATABASE_URL) {
  process.env.DATABASE_URL = process.env.TEST_DATABASE_URL;
} else {
  throw new Error(
    '[tests] TEST_DATABASE_URL is not set — copy .env.example to .env and set it before running tests.'
  );
}
