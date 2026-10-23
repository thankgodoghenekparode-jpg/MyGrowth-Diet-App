import fs from 'node:fs/promises';
import path from 'node:path';
import { createReadStream, existsSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import config from '../../config/index.js';
import { errors } from '../../lib/errors.js';
import { createS3Adapter, s3ClientFrom } from './s3.js';

/**
 * Pluggable file-storage abstraction.
 *
 * Local adapter (default): files live under UPLOAD_DIR and are served through
 * the authenticated GET /api/v1/files/:id route (no direct path exposure).
 *
 * S3 adapter: any S3-compatible object store (Amazon S3, Cloudflare R2,
 * Backblaze B2, Supabase Storage, MinIO). Objects stay private and are streamed
 * through the same authenticated route.
 *
 * Every adapter implements the same async interface — save, stat, delete,
 * createReadStream, exists — and the rest of the application only talks to this
 * module, never to a filesystem path or an SDK client directly.
 */

const localAdapter = {
  name: 'local',
  async save(sourcePath, key) {
    const dest = safeJoin(key);
    await fs.mkdir(path.dirname(dest), { recursive: true });
    await fs.rename(sourcePath, dest).catch(async (err) => {
      if (err.code === 'EXDEV') await fs.copyFile(sourcePath, dest), await fs.unlink(sourcePath);
      else throw err;
    });
    return key;
  },
  async stat(key) {
    const st = await fs.stat(safeJoin(key));
    return { size: st.size, modifiedAt: st.mtime };
  },
  async delete(key) {
    await fs.unlink(safeJoin(key)).catch(() => {});
  },
  createReadStream(key) {
    return createReadStream(safeJoin(key));
  },
  exists(key) {
    return existsSync(safeJoin(key));
  },
  absolutePath(key) {
    return safeJoin(key);
  },
};

function safeJoin(key) {
  const normalized = path.normalize(key).replace(/^(\.\.[/\\])+/, '');
  const full = path.join(config.storage.uploadDir, normalized);
  if (!full.startsWith(config.storage.uploadDir)) {
    throw errors.badRequest('Invalid storage key', 'INVALID_STORAGE_KEY');
  }
  return full;
}

let s3Instance = null;

/**
 * Build (once) the S3-compatible adapter from configuration. Constructing the
 * client does not open a connection, so a misconfigured deployment fails on the
 * first upload with a precise message rather than at boot.
 */
function s3Storage() {
  if (s3Instance) return s3Instance;
  const s = config.storage.s3;
  const missing = [
    ['S3_BUCKET', s.bucket],
    ['S3_ACCESS_KEY_ID', s.accessKeyId],
    ['S3_SECRET_ACCESS_KEY', s.secretAccessKey],
  ]
    .filter(([, value]) => !value)
    .map(([name]) => name);
  if (missing.length) {
    throw errors.internal(
      `STORAGE_ADAPTER=s3 but ${missing.join(', ')} ${missing.length === 1 ? 'is' : 'are'} not set.`,
      'STORAGE_NOT_CONFIGURED'
    );
  }
  s3Instance = createS3Adapter({
    client: s3ClientFrom(s),
    bucket: s.bucket,
    prefix: s.prefix,
  });
  return s3Instance;
}

const adapters = { local: localAdapter };

export function getStorage() {
  const name = config.storage.adapter;
  if (name === 's3') return s3Storage();
  const adapter = adapters[name];
  if (!adapter) throw errors.internal(`Unknown STORAGE_ADAPTER "${name}"`);
  return adapter;
}

/** Test hook: forget the memoised S3 adapter. */
export function resetStorageCache() {
  s3Instance = null;
}

/** File-type allowlist: pdf, audio/*, image/*, video/*, docx, txt. */
const ALLOWED_MIME = [
  'application/pdf',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'text/plain',
];
const ALLOWED_EXT = new Set(['pdf', 'docx', 'txt', 'mp3', 'wav', 'm4a', 'ogg', 'aac', 'flac',
  'mp4', 'mov', 'm4v', 'webm', 'jpg', 'jpeg', 'png', 'gif', 'webp', 'svg']);

export function validateFileType(mime, originalName = '') {
  const m = String(mime || '').toLowerCase();
  const allowed =
    ALLOWED_MIME.includes(m) ||
    m.startsWith('audio/') ||
    m.startsWith('image/') ||
    m.startsWith('video/');
  const ext = path.extname(originalName).slice(1).toLowerCase();
  if (!allowed) {
    throw errors.badRequest(
      'Unsupported file type. Allowed: PDF, DOCX, TXT, audio, images and video.',
      'UNSUPPORTED_FILE_TYPE'
    );
  }
  if (ext && !ALLOWED_EXT.has(ext)) {
    throw errors.badRequest(`File extension ".${ext}" is not allowed`, 'UNSUPPORTED_FILE_TYPE');
  }
  return true;
}

export function validateFileSize(size) {
  if (size > config.storage.maxFileBytes) {
    throw errors.payloadTooLarge(
      `File exceeds the ${Math.round(config.storage.maxFileBytes / (1024 * 1024))}MB limit`,
      'FILE_TOO_LARGE'
    );
  }
  return true;
}

/** Build a collision-free storage key for an upload. */
export function storageKeyFor(originalName) {
  const ext = (path.extname(originalName) || '').toLowerCase().replace(/[^a-z0-9.]/g, '').slice(0, 10);
  const id = randomUUID();
  return `${id}${ext}`;
}

export { localAdapter };
