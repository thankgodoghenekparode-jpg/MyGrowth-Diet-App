import { z } from 'zod';
import { AppError } from './errors.js';

/**
 * Validation middleware factory. Schemas: { body?, query?, params? }.
 * Validated values are attached to req.valid = { body, query, params }.
 * Nothing is mass-assigned: handlers must read from req.valid, never raw req.body.
 */
export function validate(schemas) {
  return (req, res, next) => {
    const result = {};
    try {
      if (schemas.body) result.body = schemas.body.parse(req.body ?? {});
      if (schemas.query) result.query = schemas.query.parse(req.query ?? {});
      if (schemas.params) result.params = schemas.params.parse(req.params ?? {});
      req.valid = result;
      return next();
    } catch (err) {
      if (err instanceof z.ZodError) {
        const details = err.issues.map((i) => ({
          path: i.path.join('.'),
          message: i.message,
        }));
        return next(
          new AppError(400, 'VALIDATION_ERROR', 'Request validation failed', details)
        );
      }
      return next(err);
    }
  };
}

// ---------------------------------------------------------------------------
// Shared schemas
// ---------------------------------------------------------------------------

export const uuidSchema = z.string().uuid('Must be a valid UUID');

export const paginationQuery = z.object({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(20),
});

export const dateSchema = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, 'Expected date format YYYY-MM-DD')
  .refine((v) => !Number.isNaN(Date.parse(v)), 'Invalid date');

export const timeSchema = z
  .string()
  .regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'Expected time format HH:mm');

export const monthSchema = z.coerce.number().int().min(1).max(12);
export const yearSchema = z.coerce.number().int().min(2000).max(2100);

export const passwordSchema = z
  .string()
  .min(8, 'Password must be at least 8 characters')
  .max(72, 'Password must be at most 72 characters');

export const emailSchema = z.string().trim().toLowerCase().email().max(254);

export const idParams = z.object({ id: uuidSchema });

export const searchQuery = z.string().trim().max(200).optional();

export default validate;
