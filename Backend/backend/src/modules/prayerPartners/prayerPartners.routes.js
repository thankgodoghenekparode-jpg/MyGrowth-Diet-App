import { Router } from 'express';
import { z } from 'zod';
import prisma from '../../db/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { validate, uuidSchema, dateSchema, timeSchema, paginationQuery } from '../../lib/validate.js';
import { paginate } from '../../lib/pagination.js';
import { audit } from '../../lib/audit.js';
import { notify } from '../../services/notifications.js';
import { partnerRequestLimiter } from '../../middleware/rateLimiters.js';
import { isoDate, dateFromISO, isValidTimeRange, nowInZone, tz } from '../../lib/dates.js';
import { DateTime } from 'luxon';

const router = Router();

// ---------------------------------------------------------------------------
// Availability
// ---------------------------------------------------------------------------

const timeRangeSchema = z
  .object({ start: timeSchema, end: timeSchema })
  .refine((r) => r.start < r.end, { message: 'start must be before end' });

const availabilityStatusSchema = z.enum(['AVAILABLE', 'UNAVAILABLE', 'TEMPORARILY_UNAVAILABLE']);

const availabilitySchema = z
  .object({
    // `availability` (legacy) and `status` (Flutter) are both accepted.
    availability: availabilityStatusSchema.optional(),
    status: availabilityStatusSchema.optional(),
    availableDays: z.array(z.coerce.number().int().min(0).max(7)).max(7).optional(),
    preferredTimeRanges: z.array(timeRangeSchema).max(10).optional(),
    // Flutter sends a single start/end pair.
    timeStart: timeSchema.optional(),
    timeEnd: timeSchema.optional(),
    timezone: z.string().trim().max(60).optional(),
    timeZone: z.string().trim().max(60).optional(),
    preferredDurationMinutes: z.coerce.number().int().min(10).max(180).optional(),
    preferredLanguage: z.string().trim().max(40).optional(),
    language: z.string().trim().max(40).optional(),
    acceptsNewRequests: z.boolean().optional(),
    acceptingRequests: z.boolean().optional(),
  })
  .refine((v) => v.availability || v.status, {
    message: 'availability or status is required',
    path: ['availability'],
  });

/** Flat, Flutter-friendly projection of a PrayerAvailability row. */
function availabilityShape(av) {
  const ranges = Array.isArray(av.preferredTimeRanges) ? av.preferredTimeRanges : [];
  const first = ranges.find(isValidTimeRange) ?? null;
  return {
    status: av.availability,
    availableDays: Array.isArray(av.availableDays) ? av.availableDays : [],
    timeStart: first ? first.start : null,
    timeEnd: first ? first.end : null,
    timeZone: av.timezone,
    preferredDurationMinutes: av.preferredDurationMinutes,
    language: av.preferredLanguage,
    acceptingRequests: av.acceptsNewRequests,
    updatedAt: av.updatedAt,
    // Raw aliases retained for other consumers.
    timezone: av.timezone,
    preferredLanguage: av.preferredLanguage,
    acceptsNewRequests: av.acceptsNewRequests,
    preferredTimeRanges: ranges,
  };
}

router.get(
  '/availability',
  asyncHandler(async (req, res) => {
    let av = await prisma.prayerAvailability.findUnique({ where: { userId: req.user.id } });
    if (!av) {
      av = await prisma.prayerAvailability.create({
        data: { userId: req.user.id, timezone: req.user.timezone || 'Africa/Lagos' },
      });
    }
    res.json({ ...availabilityShape(av), availability: av });
  })
);

router.put(
  '/availability',
  validate({ body: availabilitySchema }),
  asyncHandler(async (req, res) => {
    const b = req.valid.body;
    // Explicit mapping — never spread raw input into Prisma.
    const data = { availability: b.availability ?? b.status };
    if (b.availableDays !== undefined) data.availableDays = b.availableDays;
    if (b.preferredTimeRanges !== undefined) data.preferredTimeRanges = b.preferredTimeRanges;
    else if (b.timeStart && b.timeEnd) data.preferredTimeRanges = [{ start: b.timeStart, end: b.timeEnd }];
    const tz = b.timezone ?? b.timeZone;
    if (tz) data.timezone = tz;
    if (b.preferredDurationMinutes !== undefined) data.preferredDurationMinutes = b.preferredDurationMinutes;
    const language = b.preferredLanguage ?? b.language;
    if (language !== undefined) data.preferredLanguage = language;
    const accepts = b.acceptsNewRequests ?? b.acceptingRequests;
    if (accepts !== undefined) data.acceptsNewRequests = accepts;

    const av = await prisma.prayerAvailability.upsert({
      where: { userId: req.user.id },
      create: { userId: req.user.id, ...data },
      update: data,
    });
    res.json({ ...availabilityShape(av), availability: av });
  })
);

// ---------------------------------------------------------------------------
// Discover — overlap filtering happens server-side; exact schedules are never
// exposed to other members.
// ---------------------------------------------------------------------------

function overlaps(aRanges, bRanges) {
  if (!Array.isArray(aRanges) || !Array.isArray(bRanges)) return false;
  const toMin = (t) => Number(t.slice(0, 2)) * 60 + Number(t.slice(3, 5));
  for (const a of aRanges) {
    if (!isValidTimeRange(a)) continue;
    for (const b of bRanges) {
      if (!isValidTimeRange(b)) continue;
      if (toMin(a.start) < toMin(b.end) && toMin(b.start) < toMin(a.end)) return true;
    }
  }
  return false;
}

router.get(
  '/discover',
  validate({
    query: paginationQuery.extend({
      day: z.coerce.number().int().min(0).max(6).optional(),
      time: timeSchema.optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { page, pageSize, day, time } = req.valid.query;
    const me = req.user;
    const myAv = await prisma.prayerAvailability.findUnique({ where: { userId: me.id } });

    const [blocked, myPartnerships] = await Promise.all([
      prisma.prayerBlock.findMany({
        where: { OR: [{ blockerId: me.id }, { blockedId: me.id }] },
        select: { blockerId: true, blockedId: true },
      }),
      prisma.prayerPartnership.findMany({
        where: { OR: [{ userAId: me.id }, { userBId: me.id }], status: { in: ['ACTIVE', 'PAUSED'] } },
        select: { userAId: true, userBId: true },
      }),
    ]);
    const exclude = new Set([me.id]);
    for (const b of blocked) {
      exclude.add(b.blockerId === me.id ? b.blockedId : b.blockerId);
    }
    for (const p of myPartnerships) {
      exclude.add(p.userAId === me.id ? p.userBId : p.userAId);
    }
    const pending = await prisma.prayerPartnerRequest.findMany({
      where: {
        status: 'PENDING',
        OR: [{ requesterId: me.id }, { recipientId: me.id }],
      },
      select: { requesterId: true, recipientId: true },
    });
    const pendingSet = new Set();
    for (const r of pending) {
      const otherId = r.requesterId === me.id ? r.recipientId : r.requesterId;
      exclude.add(otherId);
      pendingSet.add(otherId);
    }

    const where = {
      availability: 'AVAILABLE',
      acceptsNewRequests: true,
      user: { id: { notIn: [...exclude] }, role: 'MEMBER', status: 'ACTIVE' },
    };

    const candidates = await prisma.prayerAvailability.findMany({
      where,
      include: { user: { select: { id: true, firstName: true, lastName: true, timezone: true } } },
      take: 200,
    });

    const filtered = candidates.filter((c) => {
      const days = Array.isArray(c.availableDays) ? c.availableDays : [];
      const ranges = Array.isArray(c.preferredTimeRanges) ? c.preferredTimeRanges : [];
      const myDays = Array.isArray(myAv?.availableDays) ? myAv.availableDays : [];
      const myRanges = Array.isArray(myAv?.preferredTimeRanges) ? myAv.preferredTimeRanges : [];

      // Day/time overlap against my own availability (server-side).
      if (myAv && (myDays.length || myRanges.length)) {
        const dayMatch =
          day != null ? days.includes(day) : myDays.length ? myDays.some((d) => days.includes(d)) : true;
        const rangeMatch = myRanges.length && ranges.length ? overlaps(myRanges, ranges) : true;
        if (!dayMatch || !rangeMatch) return false;
      }
      if (day != null && !days.includes(day)) return false;
      if (time && ranges.length && !ranges.some((r) => isValidTimeRange(r) && r.start <= time && time < r.end)) {
        return false;
      }
      return true;
    });

    const total = filtered.length;
    const startIdx = (page - 1) * pageSize;
    const slice = filtered.slice(startIdx, startIdx + pageSize);

    res.json({
      data: slice.map((c) => ({
        userId: c.user.id,
        // Flutter alias: full display name.
        name: [c.user.firstName, c.user.lastName].filter(Boolean).join(' ').trim(),
        firstName: c.user.firstName,
        // Only initials of the last name: enough to recognise, minimal exposure.
        lastInitial: `${c.user.lastName?.[0] || ''}.`,
        timezone: c.timezone,
        timeZone: c.timezone,
        preferredDurationMinutes: c.preferredDurationMinutes,
        preferredLanguage: c.preferredLanguage,
        language: c.preferredLanguage,
        hasPendingRequest: pendingSet.has(c.user.id),
        availableDays: c.availableDays ?? [],
        // Coarse signal instead of exposing the exact schedule:
        overlapsYourSchedule: myAv
          ? (Array.isArray(myAv.availableDays) && myAv.availableDays.some((d) => (c.availableDays ?? []).includes(d))) ||
            overlaps(myAv.preferredTimeRanges ?? [], c.preferredTimeRanges ?? [])
          : false,
        acceptsNewRequests: c.acceptsNewRequests,
      })),
      meta: { page, pageSize, total, totalPages: Math.max(1, Math.ceil(total / pageSize)) },
    });
  })
);

// ---------------------------------------------------------------------------
// Requests
// ---------------------------------------------------------------------------

function fullName(u) {
  return u ? [u.firstName, u.lastName].filter(Boolean).join(' ').trim() : null;
}

function requestShape(r) {
  if (!r) return null;
  return {
    ...r,
    // Flutter aliases for display names.
    senderName: fullName(r.requester),
    recipientName: fullName(r.recipient),
  };
}

router.get(
  '/requests',
  validate({
    query: paginationQuery.extend({
      // Direction accepts legacy `in`/`out` and Flutter `incoming`/`outgoing`.
      direction: z.enum(['in', 'out', 'all', 'incoming', 'outgoing']).default('all'),
      status: z.enum(['PENDING', 'ACCEPTED', 'DECLINED', 'CANCELLED', 'BLOCKED', 'REPORTED']).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { page, pageSize, status } = req.valid.query;
    const direction = req.valid.query.direction === 'incoming'
      ? 'in'
      : req.valid.query.direction === 'outgoing'
        ? 'out'
        : req.valid.query.direction;
    const or = [];
    if (direction === 'in' || direction === 'all') or.push({ recipientId: req.user.id });
    if (direction === 'out' || direction === 'all') or.push({ requesterId: req.user.id });
    const where = { OR: or };
    if (status) where.status = status;

    const result = await paginate(prisma.prayerPartnerRequest, {
      where,
      orderBy: { createdAt: 'desc' },
      include: {
        requester: { select: { id: true, firstName: true, lastName: true } },
        recipient: { select: { id: true, firstName: true, lastName: true } },
      },
      page,
      pageSize,
    });
    res.json({ data: result.data.map(requestShape), meta: result.meta });
  })
);

router.post(
  '/requests',
  partnerRequestLimiter,
  validate({
    body: z.object({
      recipientId: uuidSchema,
      message: z.string().trim().max(1000).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const requester = req.user;
    const { recipientId, message } = req.valid.body;

    if (recipientId === requester.id) {
      throw errors.badRequest('You cannot send a partner request to yourself', 'VALIDATION_ERROR');
    }

    const recipient = await prisma.user.findUnique({
      where: { id: recipientId },
      include: { availability: true },
    });
    if (!recipient || recipient.role !== 'MEMBER' || recipient.status !== 'ACTIVE') {
      throw errors.notFound('Member not found', 'NOT_FOUND');
    }

    const myBlocked = await prisma.prayerBlock.findFirst({
      where: {
        OR: [
          { blockerId: requester.id, blockedId: recipientId },
          { blockerId: recipientId, blockedId: requester.id },
        ],
      },
    });
    if (myBlocked) throw errors.forbidden('This member cannot be contacted', 'BLOCKED');

    if (!recipient.availability?.acceptsNewRequests || recipient.availability.availability !== 'AVAILABLE') {
      throw errors.conflict('This member is not accepting new partner requests right now', 'NOT_ACCEPTING_REQUESTS');
    }

    const partnership = await prisma.prayerPartnership.findFirst({
      where: {
        status: { in: ['ACTIVE', 'PAUSED'] },
        AND: [{ userAId: { in: [requester.id, recipientId] } }, { userBId: { in: [requester.id, recipientId] } }],
      },
    });
    if (partnership) throw errors.conflict('You already have a partnership with this member', 'ALREADY_PARTNERS');

    const existingEither = await prisma.prayerPartnerRequest.findFirst({
      where: {
        status: 'PENDING',
        OR: [
          { requesterId: requester.id, recipientId },
          { requesterId: recipientId, recipientId: requester.id },
        ],
      },
    });
    if (existingEither) throw errors.conflict('A pending request already exists between you', 'DUPLICATE_REQUEST');

    const request = await prisma.prayerPartnerRequest.create({
      data: { requesterId: requester.id, recipientId, message: message ?? null, status: 'PENDING' },
      include: {
        requester: { select: { id: true, firstName: true, lastName: true } },
        recipient: { select: { id: true, firstName: true, lastName: true } },
      },
    });

    await notify({
      userId: recipientId,
      eventType: 'partner_request_received',
      eventKey: request.id,
      title: 'New prayer partner request',
      body: `${requester.firstName} would like to connect as a prayer partner.`,
      data: { requestId: request.id },
    });

    const shaped = requestShape(request);
    res.status(201).json({ ...shaped, request: shaped });
  })
);

router.patch(
  '/requests/:id',
  validate({
    params: z.object({ id: uuidSchema }),
    body: z.object({
      action: z.enum(['accept', 'decline', 'cancel', 'block', 'report']),
      message: z.string().trim().max(1000).optional(),
      reason: z.string().trim().max(1000).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { action, message, reason } = req.valid.body;
    const request = await prisma.prayerPartnerRequest.findUnique({
      where: { id: req.valid.params.id },
      include: {
        requester: { select: { id: true, firstName: true, lastName: true } },
        recipient: { select: { id: true, firstName: true, lastName: true } },
      },
    });
    if (!request) throw errors.notFound('Request not found', 'NOT_FOUND');

    const isRequester = request.requesterId === req.user.id;
    const isRecipient = request.recipientId === req.user.id;
    if (!isRequester && !isRecipient) throw errors.notFound('Request not found', 'NOT_FOUND');

    if (request.status !== 'PENDING') {
      throw errors.conflict(`This request is already ${request.status.toLowerCase()}`, 'INVALID_STATE');
    }

    if (action === 'cancel' && !isRequester) {
      throw errors.forbidden('Only the sender can cancel a request', 'FORBIDDEN');
    }
    if ((action === 'accept' || action === 'decline') && !isRecipient) {
      throw errors.forbidden('Only the recipient can accept or decline', 'FORBIDDEN');
    }

    if (action === 'accept') {
      const [userAId, userBId] = [request.requesterId, request.recipientId].sort();
      const partnership = await prisma.prayerPartnership.upsert({
        where: { userAId_userBId: { userAId, userBId } },
        create: { userAId, userBId, status: 'ACTIVE', initiatedById: request.requesterId },
        update: { status: 'ACTIVE', startedAt: new Date(), pausedAt: null, endedAt: null, initiatedById: request.requesterId },
      });
      await prisma.prayerPartnerRequest.update({
        where: { id: request.id },
        data: { status: 'ACCEPTED', respondedAt: new Date() },
      });
      await notify({
        userId: request.requesterId,
        eventType: 'partner_request_accepted',
        eventKey: request.id,
        title: 'Prayer partner request accepted',
        body: `${request.recipient.firstName} accepted your prayer partner request.`,
        data: { requestId: request.id, partnershipId: partnership.id },
      });
      await audit({
        actor: req.user,
        action: 'prayer_partnership_accepted',
        targetType: 'prayer_partnership',
        targetId: partnership.id,
        details: { requestId: request.id },
        req,
      });
      const shapedAccepted = requestShape({ ...request, status: 'ACCEPTED' });
      return res.json({ ...shapedAccepted, request: shapedAccepted, partnership });
    }

    const statusMap = { decline: 'DECLINED', cancel: 'CANCELLED', block: 'BLOCKED', report: 'REPORTED' };
    const updated = await prisma.prayerPartnerRequest.update({
      where: { id: request.id },
      data: { status: statusMap[action], respondedAt: new Date() },
      include: {
        requester: { select: { id: true, firstName: true, lastName: true } },
        recipient: { select: { id: true, firstName: true, lastName: true } },
      },
    });

    if (action === 'block') {
      const [blockerId, blockedId] = isRecipient
        ? [request.recipientId, request.requesterId]
        : [request.requesterId, request.recipientId];
      await prisma.prayerBlock.upsert({
        where: { blockerId_blockedId: { blockerId, blockedId } },
        create: { blockerId, blockedId, reason: reason ?? null },
        update: { reason: reason ?? null },
      });
      await audit({
        actor: req.user,
        action: 'prayer_partner_blocked',
        targetType: 'user',
        targetId: blockedId,
        details: { requestId: request.id, reason: reason ?? null },
        req,
      });
    }

    if (action === 'report') {
      const [reporterId, reportedId] = isRecipient
        ? [request.recipientId, request.requesterId]
        : [request.requesterId, request.recipientId];
      const report = await prisma.safetyReport.create({
        data: { reporterId, reportedId, reason: reason || 'Partner request reported', details: message ?? null },
      });
      await audit({
        actor: req.user,
        action: 'prayer_partner_reported',
        targetType: 'user',
        targetId: reportedId,
        details: { reportId: report.id, requestId: request.id },
        req,
      });
    }

    if (action === 'decline') {
      await notify({
        userId: request.requesterId,
        eventType: 'partner_request_declined',
        eventKey: request.id,
        title: 'Prayer partner request declined',
        body: `${request.recipient.firstName} declined your prayer partner request.`,
        data: { requestId: request.id },
      });
    }

    const shapedUpdated = requestShape(updated);
    res.json({ ...shapedUpdated, request: shapedUpdated });
  })
);

// ---------------------------------------------------------------------------
// Partnerships
// ---------------------------------------------------------------------------

const partnerShape = (p, userId) => {
  const partner = p.userAId === userId ? p.userB : p.userA;
  const name = fullName(partner);
  return {
    id: p.id,
    status: p.status,
    startedAt: p.startedAt,
    pausedAt: p.pausedAt,
    endedAt: p.endedAt,
    // Flutter reads flat partner fields first.
    partnerId: partner.id,
    partnerName: name,
    partnerAvatarUrl: null,
    partner: { id: partner.id, firstName: partner.firstName, lastName: partner.lastName, name },
  };
};

router.get(
  '/partnerships',
  validate({
    query: paginationQuery.extend({
      status: z.enum(['ACTIVE', 'PAUSED', 'ENDED', 'BLOCKED']).optional(),
      includeEnded: z.enum(['true', 'false']).default('false'),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { page, pageSize, status, includeEnded } = req.valid.query;
    const where = { OR: [{ userAId: req.user.id }, { userBId: req.user.id }] };
    if (status) where.status = status;
    else if (includeEnded !== 'true') where.status = { in: ['ACTIVE', 'PAUSED'] };

    const result = await paginate(prisma.prayerPartnership, {
      where,
      orderBy: { updatedAt: 'desc' },
      include: {
        userA: { select: { id: true, firstName: true, lastName: true } },
        userB: { select: { id: true, firstName: true, lastName: true } },
      },
      page,
      pageSize,
    });
    res.json({ data: result.data.map((p) => partnerShape(p, req.user.id)), meta: result.meta });
  })
);

router.patch(
  '/partnerships/:id',
  validate({
    params: z.object({ id: uuidSchema }),
    body: z
      .object({
        // `action` is the legacy contract; Flutter sends a target `status`.
        action: z.enum(['pause', 'resume', 'end']).optional(),
        status: z.enum(['ACTIVE', 'PAUSED', 'ENDED']).optional(),
        confirm: z.boolean().optional(),
      })
      .refine((v) => v.action || v.status, {
        message: 'action or status is required',
        path: ['action'],
      }),
  }),
  asyncHandler(async (req, res) => {
    const b = req.valid.body;
    // Derive the action from Flutter's target status. When derived, the client
    // intent is already explicit, so confirmation is implied.
    let action = b.action;
    let confirm = b.confirm;
    if (!action && b.status) {
      action = b.status === 'PAUSED' ? 'pause' : b.status === 'ACTIVE' ? 'resume' : 'end';
      confirm = true;
    }
    const p = await prisma.prayerPartnership.findUnique({
      where: { id: req.valid.params.id },
      include: {
        userA: { select: { id: true, firstName: true, lastName: true } },
        userB: { select: { id: true, firstName: true, lastName: true } },
      },
    });
    if (!p || (p.userAId !== req.user.id && p.userBId !== req.user.id)) {
      throw errors.notFound('Partnership not found', 'NOT_FOUND');
    }

    if (action === 'end') {
      if (!confirm) throw errors.badRequest('Ending a partnership requires confirmation', 'CONFIRMATION_REQUIRED');
      if (p.status === 'ENDED') throw errors.conflict('Partnership already ended', 'INVALID_STATE');
      const updated = await prisma.prayerPartnership.update({
        where: { id: p.id },
        data: { status: 'ENDED', endedAt: new Date() },
        include: {
          userA: { select: { id: true, firstName: true, lastName: true } },
          userB: { select: { id: true, firstName: true, lastName: true } },
        },
      });
      const partnerId = p.userAId === req.user.id ? p.userBId : p.userAId;
      await notify({
        userId: partnerId,
        eventType: 'partner_request_declined',
        eventKey: `partnership-ended-${p.id}`,
        title: 'Prayer partnership ended',
        body: 'Your prayer partner has ended the partnership.',
        data: { partnershipId: p.id },
      });
      await audit({
        actor: req.user,
        action: 'prayer_partnership_ended',
        targetType: 'prayer_partnership',
        targetId: p.id,
        req,
      });
      const shaped = partnerShape(updated, req.user.id);
      return res.json({ ...shaped, partnership: shaped });
    }

    if (action === 'pause') {
      if (p.status !== 'ACTIVE') throw errors.conflict('Only active partnerships can be paused', 'INVALID_STATE');
      const updated = await prisma.prayerPartnership.update({
        where: { id: p.id },
        data: { status: 'PAUSED', pausedAt: new Date() },
        include: {
          userA: { select: { id: true, firstName: true, lastName: true } },
          userB: { select: { id: true, firstName: true, lastName: true } },
        },
      });
      await audit({ actor: req.user, action: 'prayer_partnership_paused', targetType: 'prayer_partnership', targetId: p.id, req });
      const shaped = partnerShape(updated, req.user.id);
      return res.json({ ...shaped, partnership: shaped });
    }

    if (action === 'resume') {
      if (p.status !== 'PAUSED') throw errors.conflict('Only paused partnerships can be resumed', 'INVALID_STATE');
      const updated = await prisma.prayerPartnership.update({
        where: { id: p.id },
        data: { status: 'ACTIVE', pausedAt: null },
        include: {
          userA: { select: { id: true, firstName: true, lastName: true } },
          userB: { select: { id: true, firstName: true, lastName: true } },
        },
      });
      await audit({ actor: req.user, action: 'prayer_partnership_resumed', targetType: 'prayer_partnership', targetId: p.id, req });
      const shaped = partnerShape(updated, req.user.id);
      return res.json({ ...shaped, partnership: shaped });
    }

    throw errors.badRequest('Unknown action', 'VALIDATION_ERROR');
  })
);

/**
 * POST /api/v1/prayer-partners/partnerships/:id/report
 * Report a partner for ministry review. Body: { reason, details? }.
 */
router.post(
  '/partnerships/:id/report',
  validate({
    params: z.object({ id: uuidSchema }),
    body: z.object({
      reason: z.string().trim().min(1).max(2000),
      details: z.string().trim().max(4000).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const p = await prisma.prayerPartnership.findUnique({ where: { id: req.valid.params.id } });
    if (!p || (p.userAId !== req.user.id && p.userBId !== req.user.id)) {
      throw errors.notFound('Partnership not found', 'NOT_FOUND');
    }
    const reportedId = p.userAId === req.user.id ? p.userBId : p.userAId;
    const report = await prisma.safetyReport.create({
      data: {
        reporterId: req.user.id,
        reportedId,
        partnershipId: p.id,
        reason: req.valid.body.reason,
        details: req.valid.body.details ?? null,
      },
    });
    await audit({
      actor: req.user,
      action: 'prayer_partner_reported',
      targetType: 'user',
      targetId: reportedId,
      details: { reportId: report.id, partnershipId: p.id },
      req,
    });
    res.status(201).json({ ok: true, report });
  })
);

// ---------------------------------------------------------------------------
// Prayer sessions — accept/confirm flow, only within active partnerships
// ---------------------------------------------------------------------------

const sessionShape = (s, userId) => {
  const iProposed = s.proposedById === userId;
  const partner = s.partnership
    ? s.partnership.userAId === userId
      ? s.partnership.userB
      : s.partnership.userA
    : null;
  const dateISO = isoDate(s.date);
  const startsAt = s.startTime
    ? DateTime.fromISO(`${dateISO}T${s.startTime}`, { zone: s.timezone || 'Africa/Lagos' }).toISO()
    : null;
  return {
    id: s.id,
    partnershipId: s.partnershipId,
    date: dateISO,
    startTime: s.startTime,
    // Flutter reads a combined ISO instant plus its timezone.
    startsAt,
    timeZone: s.timezone,
    durationMinutes: s.durationMinutes,
    timezone: s.timezone,
    prayerFocus: s.prayerFocus,
    meetingMethod: s.meetingMethod,
    meetingLink: s.meetingLink,
    status: s.status,
    acceptedAt: s.acceptedAt,
    completedAt: s.completedAt,
    proposedById: s.proposedById,
    partnerId: partner ? partner.id : null,
    partnerName: fullName(partner),
    myAttendanceRecorded: iProposed ? Boolean(s.proposerNote) : Boolean(s.partnerNote),
    partnerAttendanceRecorded: iProposed ? Boolean(s.partnerNote) : Boolean(s.proposerNote),
    // Visibility: each participant sees both notes of the shared session only.
    proposerNote: s.proposerNote,
    partnerNote: s.partnerNote,
    iProposed,
    partner: partner
      ? { id: partner.id, firstName: partner.firstName, lastName: partner.lastName, name: fullName(partner) }
      : undefined,
    createdAt: s.createdAt,
  };
};

const sessionInclude = {
  partnership: {
    include: {
      userA: { select: { id: true, firstName: true, lastName: true } },
      userB: { select: { id: true, firstName: true, lastName: true } },
    },
  },
};

async function loadOwnedSession(id, userId) {
  const s = await prisma.prayerSession.findUnique({ where: { id }, include: sessionInclude });
  if (!s) throw errors.notFound('Session not found', 'NOT_FOUND');
  if (s.partnership.userAId !== userId && s.partnership.userBId !== userId) {
    throw errors.notFound('Session not found', 'NOT_FOUND');
  }
  return s;
}

router.get(
  '/sessions',
  validate({
    query: paginationQuery.extend({
      from: dateSchema.optional(),
      to: dateSchema.optional(),
      // Either a concrete status, or one of the friendly windows the Flutter
      // prayer room asks for ("upcoming" = still to happen, "past" = done).
      status: z
        .enum([
          'PROPOSED',
          'ACCEPTED',
          'COMPLETED',
          'RESCHEDULED',
          'CANCELLED',
          'MISSED',
          'upcoming',
          'past',
        ])
        .optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { page, pageSize, from, to, status } = req.valid.query;
    const where = {
      partnership: { OR: [{ userAId: req.user.id }, { userBId: req.user.id }] },
    };

    if (status === 'upcoming') {
      // Sessions that are still expected to happen, from today onwards.
      where.status = { in: ['PROPOSED', 'ACCEPTED', 'RESCHEDULED'] };
      where.date = { gte: dateFromISO(nowInZone(tz(req.user)).toISODate()) };
    } else if (status === 'past') {
      where.status = { in: ['COMPLETED', 'CANCELLED', 'MISSED'] };
    } else if (status) {
      where.status = status;
    }

    if (from || to) {
      where.date = { ...(where.date ?? {}) };
      if (from) where.date.gte = dateFromISO(from);
      if (to) where.date.lte = dateFromISO(to);
    }
    const result = await paginate(prisma.prayerSession, {
      where,
      orderBy: [{ date: 'asc' }, { startTime: 'asc' }],
      include: sessionInclude,
      page,
      pageSize,
    });
    res.json({ data: result.data.map((s) => sessionShape(s, req.user.id)), meta: result.meta });
  })
);

router.post(
  '/sessions',
  validate({
    body: z
      .object({
        partnershipId: uuidSchema,
        // Legacy contract: explicit date + startTime.
        date: dateSchema.optional(),
        startTime: timeSchema.optional(),
        // Flutter sends a combined ISO instant plus a timezone.
        startsAt: z.string().trim().min(1).max(40).optional(),
        timeZone: z.string().trim().max(60).optional(),
        durationMinutes: z.coerce.number().int().min(10).max(180).default(30),
        timezone: z.string().trim().max(60).optional(),
        prayerFocus: z.string().trim().max(300).optional(),
        meetingMethod: z.string().trim().max(60).optional(),
        meetingLink: z
          .string()
          .trim()
          .max(500)
          .refine((v) => /^https?:\/\//i.test(v), 'Meeting link must be http(s)')
          .optional(),
      })
      .refine((v) => (v.date && v.startTime) || v.startsAt, {
        message: 'Provide date and startTime, or startsAt',
        path: ['startsAt'],
      }),
  }),
  asyncHandler(async (req, res) => {
    const b = req.valid.body;
    const p = await prisma.prayerPartnership.findUnique({ where: { id: b.partnershipId } });
    if (!p || (p.userAId !== req.user.id && p.userBId !== req.user.id)) {
      throw errors.notFound('Partnership not found', 'NOT_FOUND');
    }
    if (p.status !== 'ACTIVE') {
      throw errors.conflict('Sessions can only be scheduled within an active partnership', 'PARTNERSHIP_NOT_ACTIVE');
    }

    // Resolve the scheduled instant, accepting either date+startTime or startsAt.
    const timeZone = b.timeZone || b.timezone || req.user.timezone || 'Africa/Lagos';
    let dateStr = b.date;
    let startTime = b.startTime;
    if ((!dateStr || !startTime) && b.startsAt) {
      const dt = DateTime.fromISO(b.startsAt, { zone: 'utc' });
      if (!dt.isValid) throw errors.badRequest('startsAt is not a valid ISO timestamp', 'VALIDATION_ERROR');
      const local = dt.setZone(timeZone);
      dateStr = local.toFormat('yyyy-MM-dd');
      startTime = local.toFormat('HH:mm');
    }

    // Conflict check: overlapping session for either participant on the same day.
    const day = dateFromISO(dateStr);
    const sameDay = await prisma.prayerSession.findMany({
      where: {
        date: day,
        // Any session that still occupies the slot counts as a conflict. Only
        // explicitly cancelled sessions free their slot.
        status: { not: 'CANCELLED' },
        OR: [
          { partnership: { userAId: p.userAId } },
          { partnership: { userBId: p.userAId } },
          { partnership: { userAId: p.userBId } },
          { partnership: { userBId: p.userBId } },
        ],
      },
      select: { startTime: true, durationMinutes: true },
    });
    const toMin = (t) => Number(t.slice(0, 2)) * 60 + Number(t.slice(3, 5));
    const newStart = toMin(startTime);
    const newEnd = newStart + b.durationMinutes;
    const conflict = sameDay.some((s) => {
      const start = toMin(s.startTime);
      return newStart < start + s.durationMinutes && start < newEnd;
    });
    if (conflict) throw errors.conflict('That time overlaps another scheduled session', 'SESSION_CONFLICT');

    const session = await prisma.prayerSession.create({
      data: {
        partnershipId: p.id,
        proposedById: req.user.id,
        date: day,
        startTime,
        durationMinutes: b.durationMinutes,
        timezone: timeZone,
        prayerFocus: b.prayerFocus ?? null,
        meetingMethod: b.meetingMethod ?? null,
        meetingLink: b.meetingLink ?? null,
        status: 'PROPOSED',
      },
      include: sessionInclude,
    });

    const partnerId = p.userAId === req.user.id ? p.userBId : p.userAId;
    await notify({
      userId: partnerId,
      eventType: 'session_proposed',
      eventKey: session.id,
      title: 'Prayer session proposed',
      body: `A prayer session is proposed for ${b.date} at ${b.startTime}.`,
      data: { sessionId: session.id },
    });

    res.status(201).json({ session: sessionShape(session, req.user.id) });
  })
);

router.get(
  '/sessions/:id',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const s = await loadOwnedSession(req.valid.params.id, req.user.id);
    res.json({ session: sessionShape(s, req.user.id) });
  })
);

router.patch(
  '/sessions/:id',
  validate({
    params: z.object({ id: uuidSchema }),
    body: z
      .object({
        // `action` is the legacy contract; Flutter sends a target `status`.
        action: z
          .enum(['accept', 'decline', 'cancel', 'reschedule', 'complete', 'missed', 'note'])
          .optional(),
        status: z.enum(['ACCEPTED', 'CANCELLED', 'COMPLETED', 'MISSED']).optional(),
        date: dateSchema.optional(),
        startTime: timeSchema.optional(),
        durationMinutes: z.coerce.number().int().min(10).max(180).optional(),
        note: z.string().trim().max(2000).optional(),
        // Flutter marks attendance with a boolean instead of a note.
        myAttendance: z.boolean().optional(),
      })
      .refine((v) => v.action || v.status, {
        message: 'action or status is required',
        path: ['action'],
      }),
  }),
  asyncHandler(async (req, res) => {
    const { date, startTime, durationMinutes, note } = req.valid.body;
    // Derive the action from Flutter's target status when only `status` is sent.
    const statusToAction = {
      ACCEPTED: 'accept',
      CANCELLED: 'cancel',
      COMPLETED: 'complete',
      MISSED: 'missed',
    };
    const action = req.valid.body.action ?? statusToAction[req.valid.body.status];
    const s = await loadOwnedSession(req.valid.params.id, req.user.id);
    const isProposer = s.proposedById === req.user.id;
    const partnerId = s.partnership.userAId === req.user.id ? s.partnership.userBId : s.partnership.userAId;

    const allowed = {
      accept: ['PROPOSED', 'RESCHEDULED'],
      decline: ['PROPOSED', 'RESCHEDULED'],
      cancel: ['PROPOSED', 'ACCEPTED', 'RESCHEDULED'],
      reschedule: ['PROPOSED', 'ACCEPTED', 'RESCHEDULED'],
      complete: ['ACCEPTED'],
      missed: ['ACCEPTED'],
      note: ['PROPOSED', 'ACCEPTED', 'RESCHEDULED', 'COMPLETED', 'MISSED', 'CANCELLED'],
    };
    if (!allowed[action].includes(s.status)) {
      throw errors.conflict(`Cannot ${action} a session in status ${s.status}`, 'INVALID_STATE');
    }
    if (action === 'accept' && isProposer) {
      throw errors.forbidden('The proposing partner must wait for the other participant to accept', 'FORBIDDEN');
    }

    if (action === 'accept') {
      const updated = await prisma.prayerSession.update({
        where: { id: s.id },
        data: { status: 'ACCEPTED', acceptedAt: new Date(), acceptedById: req.user.id },
        include: sessionInclude,
      });
      await notify({
        userId: s.proposedById,
        eventType: 'session_accepted',
        eventKey: s.id,
        title: 'Prayer session accepted',
        body: 'Your prayer partner accepted the proposed session.',
        data: { sessionId: s.id },
      });
      return res.json({ session: sessionShape(updated, req.user.id) });
    }

    if (action === 'decline' || action === 'cancel') {
      const updated = await prisma.prayerSession.update({
        where: { id: s.id },
        data: { status: 'CANCELLED' },
        include: sessionInclude,
      });
      await notify({
        userId: partnerId,
        eventType: 'session_cancelled',
        eventKey: s.id,
        title: 'Prayer session cancelled',
        body: 'A prayer session was cancelled.',
        data: { sessionId: s.id },
      });
      return res.json({ session: sessionShape(updated, req.user.id) });
    }

    if (action === 'reschedule') {
      if (!date || !startTime) throw errors.badRequest('date and startTime are required to reschedule', 'VALIDATION_ERROR');
      const updated = await prisma.prayerSession.update({
        where: { id: s.id },
        data: {
          status: 'RESCHEDULED',
          date: dateFromISO(date),
          startTime,
          durationMinutes: durationMinutes ?? s.durationMinutes,
          acceptedAt: null,
          acceptedById: null,
        },
        include: sessionInclude,
      });
      await notify({
        userId: partnerId,
        eventType: 'session_rescheduled',
        eventKey: s.id,
        title: 'Prayer session rescheduled',
        body: `The session was moved to ${date} at ${startTime}. Please re-accept it.`,
        data: { sessionId: s.id },
      });
      return res.json({ session: sessionShape(updated, req.user.id) });
    }

    if (action === 'complete') {
      const data = { status: 'COMPLETED', completedAt: new Date() };
      // Flutter marks attendance with `myAttendance: true` (no note), so record
      // a marker note; `sessionShape` derives `myAttendanceRecorded` from it.
      const attendanceNote = note ?? (req.valid.body.myAttendance ? 'Attendance recorded.' : null);
      if (attendanceNote) {
        if (isProposer) data.proposerNote = attendanceNote;
        else data.partnerNote = attendanceNote;
      }
      const updated = await prisma.prayerSession.update({ where: { id: s.id }, data, include: sessionInclude });
      return res.json({ session: sessionShape(updated, req.user.id), selfReported: true });
    }

    if (action === 'missed') {
      const updated = await prisma.prayerSession.update({
        where: { id: s.id },
        data: { status: 'MISSED' },
        include: sessionInclude,
      });
      return res.json({ session: sessionShape(updated, req.user.id) });
    }

    if (action === 'note') {
      if (!note) throw errors.badRequest('note is required', 'VALIDATION_ERROR');
      const data = isProposer ? { proposerNote: note } : { partnerNote: note };
      const updated = await prisma.prayerSession.update({ where: { id: s.id }, data, include: sessionInclude });
      return res.json({ session: sessionShape(updated, req.user.id) });
    }

    throw errors.badRequest('Unknown action', 'VALIDATION_ERROR');
  })
);

export default router;
