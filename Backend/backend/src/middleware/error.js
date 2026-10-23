import { AppError, errors } from '../lib/errors.js';
import { logger } from '../lib/logger.js';
import config from '../config/index.js';

export function notFoundHandler(req, res, next) {
  next(errors.notFound(`Route not found: ${req.method} ${req.originalUrl}`));
}

// eslint-disable-next-line no-unused-vars
export function errorHandler(err, req, res, next) {
  let error = err;

  // Prisma known errors
  if (err?.code === 'P2002') {
    const fields = err.meta?.target ? [].concat(err.meta.target) : undefined;
    error = errors.conflict('A record with the same unique value already exists', 'DUPLICATE_RECORD', fields ? { fields } : undefined);
  } else if (err?.code === 'P2025') {
    error = errors.notFound('Resource not found', 'NOT_FOUND');
  } else if (err?.code === 'P2003') {
    error = errors.unprocessable('Related record missing or invalid', 'FOREIGN_KEY_VIOLATION');
  } else if (err?.code === 'P2021' || err?.code === 'P2022') {
    error = errors.internal('Database configuration error', 'DATABASE_ERROR');
  }

  // Multer upload errors
  if (err?.name === 'MulterError') {
    if (err.code === 'LIMIT_FILE_SIZE') {
      error = errors.payloadTooLarge('File exceeds the maximum allowed size', 'FILE_TOO_LARGE');
    } else {
      error = errors.badRequest(err.message, 'UPLOAD_ERROR');
    }
  }

  if (!(error instanceof AppError)) {
    if (!config.isProd) {
      logger.error('Unhandled error:', err?.stack || err);
    } else {
      logger.error('Unhandled error:', err?.message || String(err));
    }
    const internal = errors.internal(
      config.isProd ? 'Internal server error' : `Internal server error: ${err?.message || 'unknown'}`
    );
    return res.status(internal.status).json({
      error: { code: internal.code, message: internal.message },
    });
  }

  if (error.status >= 500) {
    logger.error(`[${error.code}] ${error.message}`, err?.stack || '');
  }

  const payload = { code: error.code, message: error.message };
  if (error.details !== undefined) payload.details = error.details;
  if (!config.isProd && error.status >= 500 && err?.stack) payload.stack = err.stack.split('\n').slice(0, 3);

  return res.status(error.status).json({ error: payload });
}
