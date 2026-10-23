import 'dotenv/config';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '..', '..');

const env = process.env.NODE_ENV || 'development';
const isProd = env === 'production';
const isTest = env === 'test' || process.env.VITEST_NODE_TEST === '1';

function int(name, fallback) {
  const v = process.env[name];
  const n = Number.parseInt(v ?? '', 10);
  return Number.isFinite(n) ? n : fallback;
}

export const config = {
  env,
  isProd,
  isTest,
  rootDir,
  port: int('PORT', 4000),
  databaseUrl: process.env.DATABASE_URL,
  testDatabaseUrl: process.env.TEST_DATABASE_URL || null,

  frontendUrl: process.env.FRONTEND_URL || 'http://localhost:3000',
  corsOrigins: (process.env.CORS_ORIGINS || process.env.FRONTEND_URL || 'http://localhost:3000')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean),
  appBaseUrl: process.env.APP_BASE_URL || 'http://localhost:4000',

  jwt: {
    accessSecret: process.env.JWT_ACCESS_SECRET || 'dev_access_secret_change_me',
    refreshSecret: process.env.JWT_REFRESH_SECRET || 'dev_refresh_secret_change_me',
    accessTtl: process.env.JWT_ACCESS_TTL || '15m',
    refreshTtlDays: int('JWT_REFRESH_TTL_DAYS', 30),
  },
  bcryptRounds: int('BCRYPT_ROUNDS', 10),
  refreshCookieName: process.env.REFRESH_COOKIE_NAME || 'mgdp_refresh',

  cronSecret: process.env.CRON_SECRET || '',

  email: {
    provider: process.env.EMAIL_PROVIDER || 'console',
    resendApiKey: process.env.RESEND_API_KEY || '',
    from: process.env.EMAIL_FROM || 'MyGrowth Diet App <no-reply@mygrowth.local>',
  },

  storage: {
    adapter: process.env.STORAGE_ADAPTER || 'local',
    uploadDir: path.resolve(rootDir, process.env.UPLOAD_DIR || './uploads'),
    maxFileBytes: int('FILE_MAX_BYTES', 50 * 1024 * 1024),
    // Cloud adapters first receive the multipart upload on a temporary local
    // path (multer streams to disk). Keep that outside the repo and outside
    // UPLOAD_DIR so it is never mistaken for a stored file.
    tempDir: path.resolve(
      rootDir,
      process.env.UPLOAD_TEMP_DIR || path.join(os.tmpdir(), 'mygrowth-uploads')
    ),
    s3: {
      bucket: process.env.S3_BUCKET || '',
      region: process.env.S3_REGION || 'auto',
      endpoint: process.env.S3_ENDPOINT || '',
      accessKeyId: process.env.S3_ACCESS_KEY_ID || '',
      secretAccessKey: process.env.S3_SECRET_ACCESS_KEY || '',
      // R2/B2/MinIO expect path-style addressing; real S3 accepts it too.
      forcePathStyle: (process.env.S3_FORCE_PATH_STYLE || 'true') !== 'false',
      prefix: process.env.S3_PREFIX || '',
    },
  },

  logLevel: process.env.LOG_LEVEL || 'info',
};

export default config;
