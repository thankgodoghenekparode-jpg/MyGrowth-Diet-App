import fs from 'node:fs/promises';
import { createReadStream } from 'node:fs';
import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  HeadObjectCommand,
  DeleteObjectCommand,
} from '@aws-sdk/client-s3';
import { errors } from '../../lib/errors.js';

/**
 * S3-compatible storage adapter.
 *
 * Works with Amazon S3, Cloudflare R2, Backblaze B2 (S3 endpoint), Supabase
 * Storage, MinIO and anything else that speaks the S3 API. Objects are private;
 * the API streams them through `GET /api/v1/files/:id`, so no bucket policy or
 * signed URL is involved.
 *
 * The adapter is created by a factory so the client can be replaced in tests
 * without touching the network.
 */

const MISSING_KEY_ERRORS = new Set(['NotFound', 'NoSuchKey', 'NotFoundException']);

function isMissing(err) {
  if (!err) return false;
  if (MISSING_KEY_ERRORS.has(err.name)) return true;
  return err.$metadata?.httpStatusCode === 404;
}

export function createS3Adapter({ client, bucket, prefix = '' } = {}) {
  if (!client) throw new Error('createS3Adapter requires an S3 client');
  if (!bucket) throw new Error('createS3Adapter requires a bucket');

  const objectKey = (key) => {
    const clean = String(key ?? '')
      .trim()
      .replace(/^\/+/, '');
    if (!clean) throw errors.badRequest('Invalid storage key', 'INVALID_STORAGE_KEY');
    const p = String(prefix || '').replace(/^\/+|\/+$/g, '');
    return p ? `${p}/${clean}` : clean;
  };

  return {
    name: 's3',

    /**
     * Upload a file multer wrote to a temporary path, then remove the temp file.
     * `contentType` is stored as object metadata so direct downloads from the
     * bucket (e.g. for debugging) render correctly.
     */
    async save(sourcePath, key, { contentType } = {}) {
      const Bucket = bucket;
      const Key = objectKey(key);
      const body = createReadStream(sourcePath);
      // The SDK's own listener reports read failures; this one only prevents an
      // unhandled 'error' event if the upload is aborted before the stream is
      // consumed (see the destroy() below).
      body.on('error', () => {});
      try {
        await client.send(
          new PutObjectCommand({
            Bucket,
            Key,
            Body: body,
            ContentType: contentType || 'application/octet-stream',
          })
        );
      } finally {
        // The object is safely in the bucket (or the upload failed) — either way
        // the temporary file is no longer needed. Destroy first: a stream still
        // opening the file would otherwise emit ENOENT after the unlink.
        body.destroy();
        await fs.unlink(sourcePath).catch(() => {});
      }
      return Key;
    },

    async stat(key) {
      const res = await client.send(
        new HeadObjectCommand({ Bucket: bucket, Key: objectKey(key) })
      );
      return {
        size: res.ContentLength ?? 0,
        modifiedAt: res.LastModified ?? null,
      };
    },

    async delete(key) {
      // S3 DELETE is idempotent: removing a missing object is not an error.
      await client.send(
        new DeleteObjectCommand({ Bucket: bucket, Key: objectKey(key) })
      );
    },

    /** Resolves to a Node Readable so the route can pipe it to the response. */
    async createReadStream(key) {
      const res = await client.send(
        new GetObjectCommand({ Bucket: bucket, Key: objectKey(key) })
      );
      return res.Body;
    },

    async exists(key) {
      try {
        await client.send(
          new HeadObjectCommand({ Bucket: bucket, Key: objectKey(key) })
        );
        return true;
      } catch (err) {
        if (isMissing(err)) return false;
        throw err;
      }
    },

    /** No filesystem path exists for object storage. */
    absolutePath() {
      throw errors.internal(
        'Object storage has no local path; stream the object instead',
        'NOT_A_LOCAL_FILE'
      );
    },
  };
}

/** Build a real S3 client from the loaded configuration. */
export function s3ClientFrom(config) {
  return new S3Client({
    region: config.region || 'auto',
    endpoint: config.endpoint || undefined,
    forcePathStyle: config.forcePathStyle !== false,
    credentials: {
      accessKeyId: config.accessKeyId,
      secretAccessKey: config.secretAccessKey,
    },
  });
}
