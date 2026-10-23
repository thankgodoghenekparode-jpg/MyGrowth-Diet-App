import { Router } from 'express';
import { z } from 'zod';
import prisma from '../../db/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { validate, uuidSchema, paginationQuery, searchQuery, emailSchema, passwordSchema } from '../../lib/validate.js';
import { paginate } from '../../lib/pagination.js';
import { audit } from '../../lib/audit.js';
import { hashPassword } from '../../lib/password.js';
import { notify } from '../../services/notifications.js';
import { publicUser } from '../auth/auth.handlers.js';

export const usersRouter = Router();

function userListShape(u) {
  return {
    ...publicUser(u),
    updatedById: u.updatedById,
    _count: u._count,
  };
}

/** GET /api/v1/admin/users — search / filter / paginate members (and admins for Main Admin views). */
usersRouter.get(
  '/users',
  validate({
    query: paginationQuery.extend({
      search: searchQuery,
      status: z.enum(['PENDING', 'ACTIVE', 'SUSPENDED', 'DEACTIVATED']).optional(),
      role: z.enum(['MEMBER', 'ADMIN', 'MAIN_ADMIN']).optional(),
      sort: z.enum(['newest', 'oldest', 'name', 'email']).default('newest'),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { page, pageSize, search, status, role, sort } = req.valid.query;
    const where = {};
    if (status) where.status = status;
    if (role) where.role = role;
    else where.role = 'MEMBER';
    if (search) {
      where.OR = [
        { firstName: { contains: search, mode: 'insensitive' } },
        { lastName: { contains: search, mode: 'insensitive' } },
        { email: { contains: search, mode: 'insensitive' } },
      ];
    }

    const orderBy =
      sort === 'oldest'
        ? { createdAt: 'asc' }
        : sort === 'name'
          ? { firstName: 'asc' }
          : sort === 'email'
            ? { email: 'asc' }
            : { createdAt: 'desc' };

    const result = await paginate(prisma.user, {
      where,
      orderBy,
      select: {
        id: true,
        email: true,
        firstName: true,
        lastName: true,
        phone: true,
        role: true,
        status: true,
        adminAccess: true,
        emailVerifiedAt: true,
        timezone: true,
        locale: true,
        avatarFileId: true,
        profileCompletedAt: true,
        lastLoginAt: true,
        createdAt: true,
        updatedAt: true,
        _count: { select: { reports: true, activityRecords: true } },
      },
      page,
      pageSize,
    });

    res.json({ data: result.data.map(userListShape), meta: result.meta });
  })
);

/** GET /api/v1/admin/users/:id — member detail with real activity counts (no private text). */
usersRouter.get(
  '/users/:id',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler(async (req, res) => {
    const user = await prisma.user.findUnique({
      where: { id: req.valid.params.id },
      include: {
        _count: {
          select: {
            reports: true,
            activityRecords: true,
            reflections: false, // private — never counted into admin views
            goals: true,
            testimonies: true,
            notifications: true,
          },
        },
      },
    });
    if (!user) throw errors.notFound('User not found', 'NOT_FOUND');
    if (user.role !== 'MEMBER' && req.user.role !== 'MAIN_ADMIN') {
      throw errors.forbidden('Only the Main Admin can view administrator accounts', 'MAIN_ADMIN_ACCESS_REQUIRED');
    }

    const [reportStats, completedActivities, sessions] = await Promise.all([
      prisma.report.groupBy({
        by: ['status'],
        where: { userId: user.id },
        _count: { _all: true },
      }),
      prisma.userActivityRecord.count({
        where: { userId: user.id, status: 'COMPLETED' },
      }),
      prisma.prayerSession.count({
        where: {
          status: 'COMPLETED',
          partnership: { OR: [{ userAId: user.id }, { userBId: user.id }] },
        },
      }),
    ]);

    res.json({
      user: publicUser(user),
      stats: {
        reports: Object.fromEntries(reportStats.map((r) => [r.status, r._count._all])),
        completedActivities,
        completedPrayerSessions: sessions,
        goals: user._count.goals,
        // reflections are intentionally excluded — private journal data.
      },
    });
  })
);

const patchUserSchema = z.object({
  firstName: z.string().trim().min(1).max(80).optional(),
  lastName: z.string().trim().min(1).max(80).optional(),
  phone: z.string().trim().max(40).nullable().optional(),
  timezone: z.string().trim().max(60).optional(),
  locale: z.string().trim().max(10).optional(),
});

/** PATCH /api/v1/admin/users/:id — member profile support (never role/status here). */
usersRouter.patch(
  '/users/:id',
  validate({ params: z.object({ id: uuidSchema }), body: patchUserSchema }),
  asyncHandler(async (req, res) => {
    const target = await prisma.user.findUnique({ where: { id: req.valid.params.id } });
    if (!target) throw errors.notFound('User not found', 'NOT_FOUND');

    if (target.role !== 'MEMBER') {
      await audit({
        actor: req.user,
        action: 'privilege_escalation_attempt',
        targetType: 'user',
        targetId: target.id,
        outcome: 'DENIED',
        details: { via: 'PATCH /admin/users/:id', targetRole: target.role },
        req,
      });
      throw errors.forbidden(
        target.role === 'MAIN_ADMIN'
          ? 'The Main Admin account cannot be modified here'
          : 'Administrators are managed through Admin Access Management',
        'ROLE_PROTECTED'
      );
    }
    if ('role' in (req.body || {}) || 'status' in (req.body || {}) || 'adminAccess' in (req.body || {}) || 'email' in (req.body || {})) {
      await audit({
        actor: req.user,
        action: 'privilege_escalation_attempt',
        targetType: 'user',
        targetId: target.id,
        outcome: 'DENIED',
        details: { via: 'PATCH /admin/users/:id', fields: Object.keys(req.body) },
        req,
      });
      throw errors.forbidden('role, status, adminAccess and email cannot be changed here', 'FIELD_NOT_EDITABLE');
    }

    const updated = await prisma.user.update({ where: { id: target.id }, data: req.valid.body });
    await audit({
      actor: req.user,
      action: 'user_updated',
      targetType: 'user',
      targetId: target.id,
      details: { fields: Object.keys(req.valid.body) },
      req,
    });
    res.json({ user: publicUser(updated) });
  })
);

async function setUserStatus(req, res, status, action) {
  const target = await prisma.user.findUnique({ where: { id: req.valid.params.id } });
  if (!target) throw errors.notFound('User not found', 'NOT_FOUND');

  if (target.role !== 'MEMBER') {
    await audit({
      actor: req.user,
      action: 'privilege_escalation_attempt',
      targetType: 'user',
      targetId: target.id,
      outcome: 'DENIED',
      details: { via: action, targetRole: target.role },
      req,
    });
    throw errors.forbidden(
      'Administrators are managed through Admin Access Management (Main Admin only)',
      'ROLE_PROTECTED'
    );
  }

  const updated = await prisma.user.update({ where: { id: target.id }, data: { status } });
  await audit({ actor: req.user, action, targetType: 'user', targetId: target.id, details: { status }, req });

  if (status === 'ACTIVE') {
    await notify({
      userId: target.id,
      eventType: 'membership_approved',
      eventKey: `approval:${new Date().toISOString().slice(0, 10)}`,
      title: 'Membership approved',
      body: 'Your membership has been approved. Welcome to the programme!',
    });
  }

  res.json({ user: publicUser(updated) });
}

/** POST /api/v1/admin/users/:id/approve */
usersRouter.post(
  '/users/:id/approve',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler((req, res) => setUserStatus(req, res, 'ACTIVE', 'member_approved'))
);

/** POST /api/v1/admin/users/:id/suspend */
usersRouter.post(
  '/users/:id/suspend',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler((req, res) => setUserStatus(req, res, 'SUSPENDED', 'member_suspended'))
);

/** POST /api/v1/admin/users/:id/reactivate */
usersRouter.post(
  '/users/:id/reactivate',
  validate({ params: z.object({ id: uuidSchema }) }),
  asyncHandler((req, res) => setUserStatus(req, res, 'ACTIVE', 'member_reactivated'))
);

// ---------------------------------------------------------------------------
// Admin accounts — Main Admin only (mounted behind requireMainAdmin)
// ---------------------------------------------------------------------------

export const adminsRouter = Router();

adminsRouter.get(
  '/',
  asyncHandler(async (req, res) => {
    const admins = await prisma.user.findMany({
      where: { role: { in: ['ADMIN', 'MAIN_ADMIN'] } },
      orderBy: [{ role: 'asc' }, { createdAt: 'asc' }],
      select: {
        id: true,
        email: true,
        firstName: true,
        lastName: true,
        role: true,
        status: true,
        adminAccess: true,
        createdAt: true,
        lastLoginAt: true,
        createdByAdmin: { select: { id: true, firstName: true, lastName: true } },
      },
    });
    res.json({ data: admins, meta: { page: 1, pageSize: admins.length || 0, total: admins.length, totalPages: 1 } });
  })
);

const createAdminSchema = z.object({
  email: emailSchema,
  firstName: z.string().trim().min(1).max(80),
  lastName: z.string().trim().min(1).max(80),
  password: passwordSchema,
});

/** POST /api/v1/admin/admins — create an Admin account (starts PENDING access). */
adminsRouter.post(
  '/',
  validate({ body: createAdminSchema }),
  asyncHandler(async (req, res) => {
    // A second Main Admin can never be created — this route always makes ADMIN.
    const existing = await prisma.user.findUnique({ where: { email: req.valid.body.email } });
    if (existing) throw errors.conflict('An account with this email already exists', 'EMAIL_TAKEN');

    const admin = await prisma.user.create({
      data: {
        email: req.valid.body.email,
        firstName: req.valid.body.firstName,
        lastName: req.valid.body.lastName,
        passwordHash: await hashPassword(req.valid.body.password),
        role: 'ADMIN',
        status: 'ACTIVE',
        adminAccess: 'PENDING', // no administrative access until granted
        emailVerifiedAt: new Date(),
        createdByAdminId: req.user.id,
      },
    });

    await audit({
      actor: req.user,
      action: 'admin_created',
      targetType: 'user',
      targetId: admin.id,
      details: { email: admin.email, adminAccess: 'PENDING' },
      req,
    });

    res.status(201).json({ user: publicUser(admin) });
  })
);

const accessSchema = z.object({
  action: z.enum(['grant', 'suspend', 'reactivate', 'revoke']),
});

/** PATCH /api/v1/admin/admins/:id/access — grant/suspend/reactivate/revoke
 * administrative access. Only the Main Admin can perform these actions; the
 * target must be an ADMIN (the Main Admin's own access cannot be changed).
 */
adminsRouter.patch(
  '/:id/access',
  validate({ params: z.object({ id: uuidSchema }), body: accessSchema }),
  asyncHandler(async (req, res) => {
    const { action } = req.valid.body;
    const target = await prisma.user.findUnique({ where: { id: req.valid.params.id } });
    if (!target || target.role === 'MEMBER') {
      throw errors.notFound('Administrator account not found', 'NOT_FOUND');
    }
    if (target.role === 'MAIN_ADMIN') {
      await audit({
        actor: req.user,
        action: 'main_admin_access_change_blocked',
        targetType: 'user',
        targetId: target.id,
        outcome: 'DENIED',
        details: { attempted: action },
        req,
      });
      throw errors.forbidden('The Main Admin account cannot be modified', 'MAIN_ADMIN_PROTECTED');
    }

    const mapping = {
      grant: { adminAccess: 'ACTIVE', status: 'ACTIVE', event: 'admin_access_granted' },
      suspend: { adminAccess: 'SUSPENDED', event: 'admin_access_suspended' },
      reactivate: { adminAccess: 'ACTIVE', status: 'ACTIVE', event: 'admin_access_reactivated' },
      revoke: { adminAccess: 'REVOKED', event: 'admin_access_revoked' },
    };
    const cfg = mapping[action];

    const data = { adminAccess: cfg.adminAccess };
    if (cfg.status) data.status = cfg.status;
    if (action === 'suspend') data.status = 'ACTIVE'; // keep account, block admin access only
    if (action === 'revoke') data.status = 'ACTIVE';

    const updated = await prisma.user.update({ where: { id: target.id }, data });

    // Suspending/revoking kills existing sessions immediately (refresh tokens).
    if (action === 'suspend' || action === 'revoke') {
      await prisma.refreshToken.updateMany({
        where: { userId: target.id, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    }

    await audit({
      actor: req.user,
      action: cfg.event,
      targetType: 'user',
      targetId: target.id,
      details: { email: target.email, adminAccess: cfg.adminAccess },
      req,
    });

    res.json({ user: publicUser(updated) });
  })
);
