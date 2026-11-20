import { Router } from 'express';
import { z } from 'zod';
import prisma from '../../db/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { paginationQuery, validate, uuidSchema } from '../../lib/validate.js';
import { audit } from '../../lib/audit.js';
import { DateTime } from 'luxon';

export const ministryPlatformAdminRouter = Router();
const pageArgs = (q) => {
  const page = q.page ?? 1;
  const pageSize = q.pageSize ?? 20;
  return { page, pageSize, skip: (page - 1) * pageSize, take: pageSize };
};

ministryPlatformAdminRouter.get('/giving/categories', asyncHandler(async (_req, res) => {
  const categories = await prisma.givingCategory.findMany({ orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }] });
  res.json({ data: { items: categories } });
}));

ministryPlatformAdminRouter.patch('/giving/categories/:id', validate({
  params: z.object({ id: uuidSchema }),
  body: z.object({
    name: z.string().trim().min(1).max(100).optional(),
    description: z.string().max(500).nullable().optional(),
    sortOrder: z.number().int().min(0).optional(),
    isActive: z.boolean().optional(),
    type: z.enum(['GENERAL_OFFERING','TITHE','MINISTRY_PARTNERSHIP','SPECIAL_SEED','MINISTRY_PROJECT','THANKSGIVING','OTHER']).optional(),
  }).refine((body) => Object.keys(body).length > 0, 'Provide at least one field to update'),
}), asyncHandler(async (req, res) => {
  const category = await prisma.givingCategory.update({ where: { id: req.valid.params.id }, data: req.valid.body });
  await audit({ actor: req.user, action: 'giving_category_updated', targetType: 'giving_category', targetId: category.id, details: { fields: Object.keys(req.valid.body) }, req });
  res.json({ data: category });
}));

ministryPlatformAdminRouter.get('/giving/transactions', validate({
  query: paginationQuery.extend({ status: z.enum(['PENDING', 'PAID', 'FAILED', 'REFUNDED']).optional() }),
}), asyncHandler(async (req, res) => {
  const { status } = req.valid.query;
  const { page, pageSize, skip, take } = pageArgs(req.valid.query);
  const where = status ? { status } : {};
  const [data, total, paid] = await Promise.all([
    prisma.givingTransaction.findMany({ where, include: { category: true }, orderBy: { createdAt: 'desc' }, skip, take }),
    prisma.givingTransaction.count({ where }),
    prisma.givingTransaction.aggregate({ where: { status: 'PAID' }, _sum: { amount: true }, _count: { _all: true } }),
  ]);
  res.json({ data: { items: data, summary: { totalPaid: Number(paid._sum.amount || 0), paidCount: paid._count._all } }, meta: { page, pageSize, total, totalPages: Math.ceil(total / pageSize) } });
}));

ministryPlatformAdminRouter.get('/giving/reports', validate({ query: z.object({
  period: z.enum(['DAILY', 'WEEKLY', 'MONTHLY']).default('DAILY'),
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
}) }), asyncHandler(async (req, res) => {
  const { period, date } = req.valid.query;
  const zone = 'Africa/Lagos';
  const anchor = date
    ? DateTime.fromISO(date, { zone }).startOf('day')
    : DateTime.now().setZone(zone);
  if (!anchor.isValid) throw errors.badRequest('Invalid report date');
  const start = period === 'DAILY' ? anchor.startOf('day')
    : period === 'WEEKLY' ? anchor.startOf('week') : anchor.startOf('month');
  const end = period === 'DAILY' ? start.plus({ days: 1 })
    : period === 'WEEKLY' ? start.plus({ weeks: 1 }) : start.plus({ months: 1 });
  const rows = await prisma.givingTransaction.findMany({
    where: { status: 'PAID', paidAt: { gte: start.toUTC().toJSDate(), lt: end.toUTC().toJSDate() } },
    include: { category: { select: { name: true, type: true } } },
    orderBy: { paidAt: 'asc' },
  });
  const categories = new Map();
  let totalAmount = 0;
  for (const row of rows) {
    const amount = Number(row.amount);
    totalAmount += amount;
    const label = row.category.name;
    const current = categories.get(label) || { name: label, count: 0, amount: 0 };
    current.count += 1;
    current.amount += amount;
    categories.set(label, current);
  }
  res.json({ data: {
    period, date: start.setZone(zone).toISODate(), timezone: zone,
    start: start.toISO(), end: end.toISO(), count: rows.length,
    totalAmount, categories: [...categories.values()],
    transactions: rows.map((row) => ({
      paidAt: row.paidAt, receiptNumber: row.receiptNumber, paymentReference: row.paymentReference,
      category: row.category.name, amount: Number(row.amount), currency: row.currency,
      donorName: row.donorName, donorEmail: row.donorEmail,
    })),
  } });
}));

ministryPlatformAdminRouter.get('/giving/partners', validate({ query: paginationQuery }), asyncHandler(async (req, res) => {
  const { page, pageSize, skip, take } = pageArgs(req.valid.query);
  const [data, total] = await Promise.all([
    prisma.givingPartner.findMany({ include: { user: { select: { id: true, firstName: true, lastName: true, email: true } } }, orderBy: { createdAt: 'desc' }, skip, take }),
    prisma.givingPartner.count(),
  ]);
  res.json({ data: { items: data }, meta: { page, pageSize, total, totalPages: Math.ceil(total / pageSize) } });
}));

const eventBody = z.object({
  title: z.string().trim().min(1).max(200), description: z.string().max(10000).nullable().optional(),
  category: z.enum(['CHURCH_SERVICE','PRAYER_MEETING','CONFERENCE','SPECIAL_PROGRAMME','BIBLE_STUDY','FASTING_PROGRAMME','ONLINE_MEETING','OTHER_EVENT']),
  bannerFileId: uuidSchema.nullable().optional(), venue: z.string().max(300).nullable().optional(),
  meetingLink: z.string().url().nullable().optional(), minister: z.string().max(200).nullable().optional(),
  startDate: z.coerce.date(), endDate: z.coerce.date().nullable().optional(), timezone: z.string().default('Africa/Lagos'),
  registrationRequired: z.boolean().default(false), maxAttendees: z.number().int().positive().nullable().optional(),
  status: z.enum(['DRAFT','PUBLISHED','CANCELLED','COMPLETED']).default('DRAFT'),
});

ministryPlatformAdminRouter.get('/events', validate({ query: paginationQuery }), asyncHandler(async (req, res) => {
  const { page, pageSize, skip, take } = pageArgs(req.valid.query);
  const [data, total] = await Promise.all([
    prisma.upcomingEvent.findMany({ include: { _count: { select: { registrations: true } }, bannerFile: { select: { id: true, originalName: true, mimeType: true } } }, orderBy: { startDate: 'desc' }, skip, take }),
    prisma.upcomingEvent.count(),
  ]);
  res.json({ data: { items: data }, meta: { page, pageSize, total, totalPages: Math.ceil(total / pageSize) } });
}));

ministryPlatformAdminRouter.get('/events/:id/registrations', validate({ params: z.object({ id: uuidSchema }), query: paginationQuery }), asyncHandler(async (req, res) => {
  const { page, pageSize, skip, take } = pageArgs(req.valid.query);
  const where = { eventId: req.valid.params.id };
  const [data, total] = await Promise.all([
    prisma.eventRegistration.findMany({ where, include: { user: { select: { id: true, firstName: true, lastName: true, email: true } } }, orderBy: { createdAt: 'desc' }, skip, take }),
    prisma.eventRegistration.count({ where }),
  ]);
  res.json({ data: { items: data }, meta: { page, pageSize, total, totalPages: Math.ceil(total / pageSize) } });
}));

ministryPlatformAdminRouter.post('/events', validate({ body: eventBody }), asyncHandler(async (req, res) => {
  const event = await prisma.upcomingEvent.create({ data: { ...req.valid.body, createdById: req.user.id, publishedAt: req.valid.body.status === 'PUBLISHED' ? new Date() : null } });
  await audit({ actor: req.user, action: 'ministry_event_created', targetType: 'upcoming_event', targetId: event.id, details: { title: event.title, status: event.status }, req });
  res.status(201).json({ data: event });
}));

ministryPlatformAdminRouter.patch('/events/:id', validate({ params: z.object({ id: uuidSchema }), body: eventBody.partial() }), asyncHandler(async (req, res) => {
  const current = await prisma.upcomingEvent.findUnique({ where: { id: req.valid.params.id } });
  if (!current) throw errors.notFound('Programme not found');
  const data = { ...req.valid.body };
  if (data.status === 'PUBLISHED' && !current.publishedAt) data.publishedAt = new Date();
  const event = await prisma.upcomingEvent.update({ where: { id: current.id }, data });
  await audit({ actor: req.user, action: 'ministry_event_updated', targetType: 'upcoming_event', targetId: event.id, details: { fields: Object.keys(data) }, req });
  res.json({ data: event });
}));

ministryPlatformAdminRouter.delete('/events/:id', validate({ params: z.object({ id: uuidSchema }) }), asyncHandler(async (req, res) => {
  const event = await prisma.upcomingEvent.findUnique({ where: { id: req.valid.params.id }, select: { id: true } });
  if (!event) throw errors.notFound('Programme not found');
  await prisma.upcomingEvent.delete({ where: { id: event.id } });
  await audit({ actor: req.user, action: 'ministry_event_deleted', targetType: 'upcoming_event', targetId: event.id, req });
  res.json({ data: { deleted: true } });
}));

const liveBody = z.object({
  title: z.string().trim().min(1).max(200), description: z.string().max(10000).nullable().optional(),
  minister: z.string().max(200).nullable().optional(), platform: z.enum(['YOUTUBE','FACEBOOK','OTHER_PLATFORM']).default('YOUTUBE'),
  streamUrl: z.string().url().nullable().optional(), embedUrl: z.string().url().nullable().optional(),
  thumbnailFileId: uuidSchema.nullable().optional(), status: z.enum(['SCHEDULED','LIVE','ENDED']).default('SCHEDULED'),
  scheduledAt: z.coerce.date(), timezone: z.string().default('Africa/Lagos'), isRecording: z.boolean().default(false),
});

ministryPlatformAdminRouter.get('/live-services', validate({ query: paginationQuery }), asyncHandler(async (req, res) => {
  const { page, pageSize, skip, take } = pageArgs(req.valid.query);
  const [data, total] = await Promise.all([
    prisma.liveService.findMany({ include: { thumbnailFile: { select: { id: true, originalName: true, mimeType: true } } }, orderBy: { scheduledAt: 'desc' }, skip, take }), prisma.liveService.count(),
  ]);
  res.json({ data: { items: data }, meta: { page, pageSize, total, totalPages: Math.ceil(total / pageSize) } });
}));

ministryPlatformAdminRouter.post('/live-services', validate({ body: liveBody }), asyncHandler(async (req, res) => {
  if (req.valid.body.status === 'LIVE') throw errors.badRequest('Create the service as scheduled, then start it');
  const service = await prisma.liveService.create({ data: { ...req.valid.body, createdById: req.user.id } });
  await audit({ actor: req.user, action: 'live_service_created', targetType: 'live_service', targetId: service.id, details: { title: service.title }, req });
  res.status(201).json({ data: service });
}));

ministryPlatformAdminRouter.patch('/live-services/:id', validate({ params: z.object({ id: uuidSchema }), body: liveBody.partial() }), asyncHandler(async (req, res) => {
  const current = await prisma.liveService.findUnique({ where: { id: req.valid.params.id } });
  if (!current) throw errors.notFound('Live service not found');
  const patch = { ...req.valid.body };
  if (patch.status === 'LIVE' && current.status !== 'LIVE') {
    patch.startedAt = new Date();
    patch.endedAt = null;
  } else if (patch.status === 'ENDED' && current.status !== 'ENDED') {
    patch.endedAt = new Date();
  }
  if (patch.status === 'LIVE') {
    const otherLive = await prisma.liveService.findFirst({ where: { status: 'LIVE', id: { not: current.id } } });
    if (otherLive) throw errors.conflict('End the current live service before starting another');
  }
  const service = await prisma.liveService.update({ where: { id: current.id }, data: patch });
  await audit({ actor: req.user, action: 'live_service_updated', targetType: 'live_service', targetId: service.id, details: { fields: Object.keys(patch) }, req });
  res.json({ data: service });
}));

ministryPlatformAdminRouter.delete('/live-services/:id', validate({ params: z.object({ id: uuidSchema }) }), asyncHandler(async (req, res) => {
  const service = await prisma.liveService.findUnique({ where: { id: req.valid.params.id }, select: { id: true } });
  if (!service) throw errors.notFound('Live service not found');
  await prisma.liveService.delete({ where: { id: service.id } });
  await audit({ actor: req.user, action: 'live_service_deleted', targetType: 'live_service', targetId: service.id, req });
  res.json({ data: { deleted: true } });
}));

ministryPlatformAdminRouter.get('/prayer-requests', validate({ query: paginationQuery.extend({ unread: z.enum(['true','false']).optional() }) }), asyncHandler(async (req, res) => {
  const { page, pageSize, skip, take, unread } = req.valid.query;
  const where = unread === undefined ? {} : { isRead: unread !== 'true' };
  const [data, total] = await Promise.all([
    prisma.prayerRequest.findMany({ where, orderBy: { createdAt: 'desc' }, skip, take }), prisma.prayerRequest.count({ where }),
  ]);
  res.json({ data: { items: data }, meta: { page, pageSize, total, totalPages: Math.ceil(total / pageSize) } });
}));

ministryPlatformAdminRouter.patch('/prayer-requests/:id', validate({ params: z.object({ id: uuidSchema }), body: z.object({ isRead: z.boolean() }) }), asyncHandler(async (req, res) => {
  const result = await prisma.prayerRequest.updateMany({ where: { id: req.valid.params.id }, data: { isRead: req.valid.body.isRead } });
  if (!result.count) throw errors.notFound('Prayer request not found');
  await audit({ actor: req.user, action: 'prayer_request_reviewed', targetType: 'prayer_request', targetId: req.valid.params.id, details: { isRead: req.valid.body.isRead }, req });
  res.json({ data: { id: req.valid.params.id, isRead: req.valid.body.isRead } });
}));
