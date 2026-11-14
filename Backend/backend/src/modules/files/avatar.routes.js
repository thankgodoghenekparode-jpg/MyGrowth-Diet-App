import prisma from '../../db/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { getStorage } from '../../services/storage/index.js';

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * GET /api/v1/avatars/:userId — public profile photo.
 *
 * Profile photos are intentionally readable without a bearer token so Flutter
 * web can render them with a plain `NetworkImage` (browsers do not attach the
 * app's Authorization header to image requests). Only the avatar file is
 * exposed here — never other uploads, which stay behind the authenticated
 * `/api/v1/files/:id` route.
 */
export const avatarHandler = asyncHandler(async (req, res) => {
  const userId = String(req.params.userId || '');
  if (!UUID_RE.test(userId)) {
    throw errors.notFound('Avatar not found', 'NOT_FOUND');
  }

  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { avatarFile: true },
  });
  const file = user?.avatarFile;
  if (!file) throw errors.notFound('Avatar not found', 'NOT_FOUND');

  const storage = getStorage();
  if (!(await storage.exists(file.storageKey))) {
    throw errors.notFound('Avatar content is missing', 'FILE_MISSING');
  }

  res.setHeader('Content-Type', file.mimeType);
  res.setHeader('Content-Length', String(file.sizeBytes));
  res.setHeader('Cache-Control', 'public, max-age=3600');
  res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
  res.setHeader(
    'Content-Disposition',
    `inline; filename="${encodeURIComponent(file.originalName)}"`
  );

  const stream = await storage.createReadStream(file.storageKey);
  stream.on('error', () => {
    if (!res.headersSent) {
      res
        .status(500)
        .json({ error: { code: 'FILE_READ_ERROR', message: 'Failed to read file' } });
    } else {
      res.destroy();
    }
  });
  stream.pipe(res);
});
