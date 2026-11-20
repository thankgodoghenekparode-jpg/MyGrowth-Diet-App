import { Router } from 'express';
import prisma from '../../db/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { requireAuth, requireApprovedMember } from '../../middleware/auth.js';
import { validate, emailSchema } from '../../lib/validate.js';
import { z } from 'zod';

const router = Router();
router.use((req, res, next) => {
  if (!req.get('authorization')) return next();
  return requireAuth(req, res, (error) => {
    if (error) return next(error);
    return requireApprovedMember(req, res, next);
  });
});

/** GET / — list upcoming published events */
router.get('/', asyncHandler(async (req, res) => {
  await prisma.upcomingEvent.updateMany({
    where: { status: 'PUBLISHED', startDate: { lt: new Date() } },
    data: { status: 'COMPLETED' },
  });
  const page = Math.max(1, parseInt(req.query.page) || 1);
  const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 20));
  const skip = (page - 1) * limit;

  const where = {
    status: 'PUBLISHED',
    startDate: { gte: new Date() },
  };
  if (req.query.category) where.category = req.query.category;

  const [events, total] = await Promise.all([
    prisma.upcomingEvent.findMany({
      where,
      orderBy: { startDate: 'asc' },
      skip,
      take: limit,
      include: {
        _count: { select: { registrations: true } },
        bannerFile: { select: { id: true, originalName: true, mimeType: true } },
        registrations: {
          where: { userId: req.user?.id ?? null, isGuest: false },
          select: { id: true },
          take: 1,
        },
      },
    }),
    prisma.upcomingEvent.count({ where }),
  ]);

  const data = events.map((e) => ({
    ...e,
    registrationCount: e._count.registrations,
    isRegistered: e.registrations.length > 0,
    _count: undefined,
    registrations: undefined,
  }));

  res.json({ data: { events: data, total, page, totalPages: Math.ceil(total / limit) } });
}));

/** GET /past — list completed events */
router.get('/past', asyncHandler(async (req, res) => {
  await prisma.upcomingEvent.updateMany({
    where: { status: 'PUBLISHED', startDate: { lt: new Date() } },
    data: { status: 'COMPLETED' },
  });
  const page = Math.max(1, parseInt(req.query.page) || 1);
  const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 20));
  const skip = (page - 1) * limit;

  const where = { status: 'COMPLETED' };
  if (req.query.category) where.category = req.query.category;

  const [events, total] = await Promise.all([
    prisma.upcomingEvent.findMany({
      where,
      orderBy: { startDate: 'desc' },
      skip,
      take: limit,
      include: {
        _count: { select: { registrations: true } },
        bannerFile: { select: { id: true, originalName: true, mimeType: true } },
      },
    }),
    prisma.upcomingEvent.count({ where }),
  ]);

  const data = events.map((e) => ({
    ...e,
    registrationCount: e._count.registrations,
    _count: undefined,
  }));

  res.json({ data: { events: data, total, page, totalPages: Math.ceil(total / limit) } });
}));

/** GET /:id — event detail */
router.get('/:id', asyncHandler(async (req, res) => {
  const event = await prisma.upcomingEvent.findUnique({
    where: { id: req.params.id },
    include: {
      _count: { select: { registrations: true } },
      bannerFile: { select: { id: true, originalName: true, mimeType: true } },
      registrations: {
        where: { userId: req.user?.id ?? null, isGuest: false },
        select: { id: true },
        take: 1,
      },
    },
  });
  if (!event) throw errors.notFound('Event not found');
  if (event.status !== 'PUBLISHED' && !(req.user && req.user.role !== 'MEMBER' && req.user.adminAccess === 'ACTIVE')) {
    throw errors.notFound('Event not found');
  }

  res.json({
    data: {
      ...event,
      registrationCount: event._count.registrations,
      isRegistered: event.registrations.length > 0,
      _count: undefined,
      registrations: undefined,
    },
  });
}));

/** POST /:id/register — register for an event */
router.post('/:id/register', validate({ body: z.object({
  guestName: z.string().trim().min(1).max(160).optional(),
  guestEmail: emailSchema.optional(),
  guestPhone: z.string().trim().max(40).optional(),
}) }), asyncHandler(async (req, res) => {
  const event = await prisma.upcomingEvent.findUnique({
    where: { id: req.params.id },
    include: { _count: { select: { registrations: true } } },
  });
  if (!event) throw errors.notFound('Event not found');
  if (event.status !== 'PUBLISHED') throw errors.badRequest('This event is not accepting registrations');
  if (req.user?.status === 'PENDING') {
    throw errors.forbidden('Your membership is awaiting approval.', 'MEMBERSHIP_PENDING_APPROVAL');
  }

  const isGuest = !req.user;
  if (isGuest && (!req.valid.body.guestName || !req.valid.body.guestEmail)) {
    throw errors.badRequest('Name and email are required for guest registration');
  }

  if (event.maxAttendees && event._count.registrations >= event.maxAttendees) {
    throw errors.conflict('This event has reached maximum capacity');
  }

  if (!isGuest) {
    const existing = await prisma.eventRegistration.findUnique({
      where: { eventId_userId: { eventId: event.id, userId: req.user.id } },
    });
    if (existing) throw errors.conflict('You are already registered for this event');
  } else {
    const existing = await prisma.eventRegistration.findFirst({
      where: {
        eventId: event.id,
        userId: null,
        guestEmail: req.valid.body.guestEmail,
      },
      select: { id: true },
    });
    if (existing) throw errors.conflict('This email is already registered for the programme');
  }

  const registration = await prisma.eventRegistration.create({
    data: {
      eventId: event.id,
      userId: req.user?.id ?? null,
      guestName: isGuest ? req.valid.body.guestName : null,
      guestEmail: isGuest ? req.valid.body.guestEmail : null,
      guestPhone: isGuest ? req.valid.body.guestPhone || null : null,
      isGuest,
    },
  });

  res.status(201).json({ data: { registered: true, guest: isGuest, registrationId: registration.id } });
}));

/** DELETE /:id/register — unregister from an event */
router.delete('/:id/register', asyncHandler(async (req, res) => {
  if (!req.user) throw errors.unauthorized('Sign in to cancel this registration');
  const existing = await prisma.eventRegistration.findUnique({
    where: { eventId_userId: { eventId: req.params.id, userId: req.user.id } },
  });
  if (!existing) throw errors.notFound('You are not registered for this event');

  await prisma.eventRegistration.delete({ where: { id: existing.id } });
  res.json({ data: { registered: false } });
}));

export default router;
