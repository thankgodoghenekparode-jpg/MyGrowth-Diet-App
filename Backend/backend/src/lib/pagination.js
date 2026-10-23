import { errors } from './errors.js';

/** Consistent pagination envelope: {data, meta:{page,pageSize,total,totalPages}} */
export function buildMeta(page, pageSize, total) {
  return {
    page,
    pageSize,
    total,
    totalPages: Math.max(1, Math.ceil(total / pageSize)),
  };
}

export function pageValues(query = {}) {
  const page = Number.parseInt(query.page ?? '1', 10);
  const pageSize = Number.parseInt(query.pageSize ?? '20', 10);
  if (!Number.isFinite(page) || page < 1) {
    throw errors.badRequest('page must be an integer >= 1', 'VALIDATION_ERROR');
  }
  if (!Number.isFinite(pageSize) || pageSize < 1 || pageSize > 100) {
    throw errors.badRequest('pageSize must be between 1 and 100', 'VALIDATION_ERROR');
  }
  return { page, pageSize, skip: (page - 1) * pageSize, take: pageSize };
}

export function paginated(data, { page, pageSize, total }) {
  return { data, meta: buildMeta(page, pageSize, total) };
}

/**
 * Run a paginated prisma query.
 * @param {{findMany:Function,count:Function}} model Prisma model delegate
 * @param {{where?:object,orderBy?:object,include?:object,select?:object,page:number,pageSize:number}} opts
 */
export async function paginate(model, opts) {
  const { where, orderBy, include, select, page, pageSize } = opts;
  const skip = (page - 1) * pageSize;
  const [data, total] = await Promise.all([
    model.findMany({
      where,
      orderBy,
      include,
      select,
      skip,
      take: pageSize,
    }),
    model.count({ where }),
  ]);
  return paginated(data, { page, pageSize, total });
}
