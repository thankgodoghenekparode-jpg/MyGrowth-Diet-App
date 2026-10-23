/**
 * Application error with an HTTP status and a stable machine-readable code.
 * The central error handler turns these into {error:{code,message,details?}}.
 */
export class AppError extends Error {
  constructor(status, code, message, details) {
    super(message);
    this.name = 'AppError';
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

export const errors = {
  badRequest: (message = 'Bad request', code = 'BAD_REQUEST', details) =>
    new AppError(400, code, message, details),
  unauthorized: (message = 'Authentication required', code = 'UNAUTHORIZED') =>
    new AppError(401, code, message),
  forbidden: (message = 'Forbidden', code = 'FORBIDDEN', details) =>
    new AppError(403, code, message, details),
  notFound: (message = 'Resource not found', code = 'NOT_FOUND') =>
    new AppError(404, code, message),
  conflict: (message = 'Conflict', code = 'CONFLICT', details) =>
    new AppError(409, code, message, details),
  payloadTooLarge: (message = 'Payload too large', code = 'PAYLOAD_TOO_LARGE') =>
    new AppError(413, code, message),
  unprocessable: (message = 'Unprocessable request', code = 'UNPROCESSABLE', details) =>
    new AppError(422, code, message, details),
  internal: (message = 'Internal server error', code = 'INTERNAL_ERROR') =>
    new AppError(500, code, message),
};

/** Wrap an async route handler so rejections reach the error middleware (Express 4). */
export function asyncHandler(fn) {
  return function wrapped(req, res, next) {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}
