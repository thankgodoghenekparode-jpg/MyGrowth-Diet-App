import { Router } from 'express';
import prisma from '../../db/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { requireAuth, requireApprovedMember } from '../../middleware/auth.js';

const router = Router();
router.use(requireAuth, requireApprovedMember);

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
        registrations: {
          where: { userId: req.user.id },
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
      include: { _count: { select: { registrations: true } } },
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
      registrations: {
        where: { userId: req.user.id },
        select: { id: true },
        take: 1,
      },
    },
  });
  if (!event) throw errors.notFound('Event not found');
  if (event.status !== 'PUBLISHED' && !(req.user.role !== 'MEMBER' && req.user.adminAccess === 'ACTIVE')) {
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
router.post('/:id/register', asyncHandler(async (req, res) => {
  const event = await prisma.upcomingEvent.findUnique({
    where: { id: req.params.id },
    include: { _count: { select: { registrations: true } } },
  });
  if (!event) throw errors.notFound('Event not found');
  if (event.status !== 'PUBLISHED') throw errors.badRequest('This event is not accepting registrations');

  if (event.maxAttendees && event._count.registrations >= event.maxAttendees) {
    throw errors.conflict('This event has reached maximum capacity');
  }

  const existing = await prisma.eventRegistration.findUnique({
    where: { eventId_userId: { eventId: event.id, userId: req.user.id } },
  });
  if (existing) throw errors.conflict('You are already registered for this event');

  const registration = await prisma.eventRegistration.create({
    data: { eventId: event.id, userId: req.user.id },
  });

  res.status(201).json({ data: { registered: true, registrationId: registration.id } });
}));

/** DELETE /:id/register — unregister from an event */
router.delete('/:id/register', asyncHandler(async (req, res) => {
  const existing = await prisma.eventRegistration.findUnique({
    where: { eventId_userId: { eventId: req.params.id, userId: req.user.id } },
  });
  if (!existing) throw errors.notFound('You are not registered for this event');

  await prisma.eventRegistration.delete({ where: { id: existing.id } });
  res.json({ data: { registered: false } });
}));

export default router;
