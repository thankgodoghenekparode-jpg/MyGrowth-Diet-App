import multer from 'multer';
import path from 'node:path';
import fs from 'node:fs';
import config from '../config/index.js';
import {
  getStorage,
  validateFileType,
  validateFileSize,
  storageKeyFor,
} from '../services/storage/index.js';

// Multer writes a multipart upload to disk before the storage adapter sees it.
// In local mode that is the upload directory itself; in cloud mode it is a
// temporary directory, and the adapter uploads the file and deletes it again.
// Neither directory is guaranteed to exist on a fresh container/disk, and
// multer does not create it, so do that once at startup.
export const incomingDir =
  config.storage.adapter === 'local' ? config.storage.uploadDir : config.storage.tempDir;

fs.mkdirSync(incomingDir, { recursive: true });

/**
 * Multipart upload middleware shared by the admin and member file routes.
 *
 * Files land under a collision-free key, are validated for type and size, and
 * are then handed to the storage adapter. Nothing is ever served from a public
 * static path.
 */
export const uploadSingle = multer({
  storage: multer.diskStorage({
    destination: (req, file, cb) => cb(null, incomingDir),
    filename: (req, file, cb) => cb(null, storageKeyFor(file.originalname)),
  }),
  limits: { fileSize: config.storage.maxFileBytes, files: 1 },
  fileFilter: (req, file, cb) => {
    try {
      validateFileType(file.mimetype, file.originalname);
      cb(null, true);
    } catch (err) {
      cb(err);
    }
  },
}).single('file');

/**
 * Persist an uploaded multer file as a `File` row and return the column data.
 *
 * The local adapter receives the file already in place (multer wrote it into
 * the upload directory). Cloud adapters are given the temporary path, upload
 * it, and remove the temporary copy.
 */
export async function persistUpload(req, uploadedById) {
  const file = req.file;
  const storage = getStorage();
  const key = file.filename;
  if (storage.name !== 'local') {
    try {
      await storage.save(file.path, key, { contentType: file.mimetype });
    } catch (err) {
      await fs.promises.unlink(file.path).catch(() => {});
      throw err;
    }
  }
  return {
    originalName: path.basename(file.originalname).slice(0, 255),
    mimeType: file.mimetype,
    sizeBytes: file.size,
    storageKey: key,
    storageAdapter: storage.name,
    uploadedById,
  };
}

export { validateFileType, validateFileSize };
