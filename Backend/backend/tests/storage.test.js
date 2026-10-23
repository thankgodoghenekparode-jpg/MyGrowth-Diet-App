import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { Readable } from 'node:stream';
import { createS3Adapter } from '../src/services/storage/s3.js';
import { getStorage, resetStorageCache } from '../src/services/storage/index.js';
import config from '../src/config/index.js';

/**
 * An in-memory stand-in for S3Client. It records every command and keeps the
 * objects, so the adapter's behaviour can be tested without network or
 * credentials.
 */
class FakeS3Client {
  constructor() {
    this.calls = [];
    this.objects = new Map();
    this.failWith = null;
  }

  key(input) {
    return `${input.Bucket}/${input.Key}`;
  }

  async send(command) {
    const name = command.constructor.name;
    this.calls.push({ name, input: command.input });
    if (this.failWith) throw this.failWith;

    if (name === 'PutObjectCommand') {
      const chunks = [];
      for await (const chunk of command.input.Body) chunks.push(chunk);
      this.objects.set(this.key(command.input), {
        body: Buffer.concat(chunks),
        contentType: command.input.ContentType,
      });
      return {};
    }

    if (name === 'HeadObjectCommand') {
      const object = this.objects.get(this.key(command.input));
      if (!object) throw notFound();
      return {
        ContentLength: object.body.length,
        LastModified: new Date('2027-01-02T03:04:05.000Z'),
      };
    }

    if (name === 'GetObjectCommand') {
      const object = this.objects.get(this.key(command.input));
      if (!object) throw notFound();
      return { Body: Readable.from([object.body]) };
    }

    if (name === 'DeleteObjectCommand') {
      this.objects.delete(this.key(command.input));
      return {};
    }

    throw new Error(`Unexpected command ${name}`);
  }
}

function notFound() {
  const err = new Error('Not Found');
  err.name = 'NotFound';
  err.$metadata = { httpStatusCode: 404 };
  return err;
}

async function tempFile(contents = 'report body') {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'mgdp-s3-test-'));
  const file = path.join(dir, 'upload.txt');
  await fs.writeFile(file, contents);
  return file;
}

function adapterUnderTest(overrides = {}) {
  const client = new FakeS3Client();
  const adapter = createS3Adapter({ client, bucket: 'mygrowth-files', ...overrides });
  return { client, adapter };
}

test('the S3 adapter uploads a temp file and removes the temp copy', async () => {
  const { client, adapter } = adapterUnderTest();
  const source = await tempFile('weekly report');

  const key = await adapter.save(source, 'stored.txt', { contentType: 'text/plain' });

  assert.equal(key, 'stored.txt');
  assert.equal(adapter.name, 's3');
  assert.equal(client.calls[0].name, 'PutObjectCommand');
  assert.equal(client.calls[0].input.Bucket, 'mygrowth-files');
  assert.equal(client.calls[0].input.Key, 'stored.txt');
  assert.equal(client.calls[0].input.ContentType, 'text/plain');

  const stored = client.objects.get('mygrowth-files/stored.txt');
  assert.equal(stored.body.toString('utf8'), 'weekly report');
  await assert.rejects(fs.access(source), 'the temporary upload should be deleted');
});

test('the S3 adapter applies an optional key prefix', async () => {
  const { client, adapter } = adapterUnderTest({ prefix: 'mygrowth/prod/' });
  const source = await tempFile();

  const key = await adapter.save(source, '/song.mp3', { contentType: 'audio/mpeg' });

  assert.equal(key, 'mygrowth/prod/song.mp3');
  assert.ok(client.objects.has('mygrowth-files/mygrowth/prod/song.mp3'));
});

test('the S3 adapter removes the temp file even when the upload fails', async () => {
  const { client, adapter } = adapterUnderTest();
  const source = await tempFile('doomed');
  client.failWith = new Error('network down');

  await assert.rejects(adapter.save(source, 'stored.txt'), /network down/);
  await assert.rejects(fs.access(source), 'the temporary upload should still be deleted');
});

test('the S3 adapter stats an object', async () => {
  const { adapter } = adapterUnderTest();
  const source = await tempFile('1234567890');
  await adapter.save(source, 'a.txt');

  const stat = await adapter.stat('a.txt');
  assert.equal(stat.size, 10);
  assert.equal(stat.modifiedAt.toISOString(), '2027-01-02T03:04:05.000Z');
});

test('the S3 adapter reports existence without throwing', async () => {
  const { adapter } = adapterUnderTest();
  assert.equal(await adapter.exists('missing.txt'), false);

  const source = await tempFile();
  await adapter.save(source, 'present.txt');
  assert.equal(await adapter.exists('present.txt'), true);
});

test('the S3 adapter streams an object', async () => {
  const { adapter } = adapterUnderTest();
  const source = await tempFile('streamed bytes');
  await adapter.save(source, 'stream.txt');

  const stream = await adapter.createReadStream('stream.txt');
  const chunks = [];
  for await (const chunk of stream) chunks.push(chunk);
  assert.equal(Buffer.concat(chunks).toString('utf8'), 'streamed bytes');
});

test('the S3 adapter deletes an object and ignores a missing one', async () => {
  const { adapter, client } = adapterUnderTest();
  const source = await tempFile();
  await adapter.save(source, 'gone.txt');

  await adapter.delete('gone.txt');
  assert.equal(client.objects.has('mygrowth-files/gone.txt'), false);

  // Deleting twice is not an error (S3 DELETE is idempotent).
  await assert.doesNotReject(adapter.delete('gone.txt'));
});

test('the S3 adapter refuses an empty storage key', async () => {
  const { adapter } = adapterUnderTest();
  await assert.rejects(adapter.exists(''), (err) => err.code === 'INVALID_STORAGE_KEY');
  await assert.rejects(adapter.save('', '  '), (err) => err.code === 'INVALID_STORAGE_KEY');
});

test('selecting s3 storage without credentials fails with a precise message', () => {
  const saved = { ...config.storage };
  try {
    config.storage.adapter = 's3';
    config.storage.s3 = {
      ...config.storage.s3,
      bucket: '',
      accessKeyId: '',
      secretAccessKey: '',
    };
    resetStorageCache();

    assert.throws(
      () => getStorage(),
      (err) =>
        err.code === 'STORAGE_NOT_CONFIGURED' &&
        err.message.includes('S3_BUCKET') &&
        err.message.includes('S3_ACCESS_KEY_ID') &&
        err.message.includes('S3_SECRET_ACCESS_KEY')
    );
  } finally {
    config.storage.adapter = saved.adapter;
    config.storage.s3 = saved.s3;
    config.storage.uploadDir = saved.uploadDir;
    config.storage.tempDir = saved.tempDir;
    config.storage.maxFileBytes = saved.maxFileBytes;
    resetStorageCache();
  }

  // The default configuration still resolves to the local adapter.
  assert.equal(getStorage().name, 'local');
});
