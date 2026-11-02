import { Router } from 'express';
import { z } from 'zod';
import prisma from '../../db/index.js';
import { validate } from '../../middleware/validate.js';
import { errors } from '../../lib/errors.js';
import { auditLog } from '../../lib/audit.js';

export const adminConnectRouter = Router();

const connectSchema = z.object({
  title: z.string().min(1).max(200),
  url: z.string().url().max(2048),
  description: z.string().max(500).nullable().optional(),
  icon: z.string().max(100).nullable().optional(),
  qrCodeUrl: z.string().url().max(2048).nullable().optional(),
  sortOrder: z.coerce.number().int().optional(),
  isActive: z.boolean().optional(),
});

adminConnectRouter.get('/connect-links', async (req, res, next) => {
  try {
    const links = await prisma.connectLink.findMany({
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
    });
    res.json({ links });
  } catch (err) {
    next(err);
  }
});

adminConnectRouter.post('/connect-links', validate({ body: connectSchema }), async (req, res, next) => {
  try {
    const link = await prisma.connectLink.create({
      data: {
        title: req.body.title.trim(),
        url: req.body.url.trim(),
        description: req.body.description?.trim() || null,
        icon: req.body.icon?.trim() || null,
        qrCodeUrl: req.body.qrCodeUrl?.trim() || null,
        sortOrder: req.body.sortOrder ?? 0,
        isActive: req.body.isActive ?? true,
        createdById: req.user?.id ?? null,
      },
    });
    await auditLog({
      req,
      actorId: req.user?.id ?? null,
      actorRole: req.user?.role ?? null,
      actorEmail: req.user?.email ?? null,
      targetType: 'CONNECT_LINK',
      targetId: link.id,
      action: 'connect_link_created',
      outcome: 'SUCCESS',
      details: { title: link.title },
    });
    res.status(201).json({ link });
  } catch (err) {
    next(err);
  }
});

adminConnectRouter.patch('/connect-links/:id', validate({ body: connectSchema.partial() }), async (req, res, next) => {
  try {
    const existing = await prisma.connectLink.findUnique({ where: { id: req.params.id } });
    if (!existing) throw errors.notFound('Connect link not found');
    const data = {};
    if (req.body.title !== undefined) data.title = req.body.title.trim();
    if (req.body.url !== undefined) data.url = req.body.url.trim();
    if (req.body.description !== undefined) data.description = req.body.description?.trim() || null;
    if (req.body.icon !== undefined) data.icon = req.body.icon?.trim() || null;
    if (req.body.qrCodeUrl !== undefined) data.qrCodeUrl = req.body.qrCodeUrl?.trim() || null;
    if (req.body.sortOrder !== undefined) data.sortOrder = req.body.sortOrder;
    if (req.body.isActive !== undefined) data.isActive = req.body.isActive;
    const link = await prisma.connectLink.update({ where: { id: req.params.id }, data });
    await auditLog({
      req,
      actorId: req.user?.id ?? null,
      actorRole: req.user?.role ?? null,
      actorEmail: req.user?.email ?? null,
      targetType: 'CONNECT_LINK',
      targetId: link.id,
      action: 'connect_link_updated',
      outcome: 'SUCCESS',
      details: { title: link.title },
    });
    res.json({ link });
  } catch (err) {
    next(err);
  }
});

adminConnectRouter.delete('/connect-links/:id', async (req, res, next) => {
  try {
    const existing = await prisma.connectLink.findUnique({ where: { id: req.params.id } });
    if (!existing) throw errors.notFound('Connect link not found');
    await prisma.connectLink.delete({ where: { id: req.params.id } });
    await auditLog({
      req,
      actorId: req.user?.id ?? null,
      actorRole: req.user?.role ?? null,
      actorEmail: req.user?.email ?? null,
      targetType: 'CONNECT_LINK',
      targetId: req.params.id,
      action: 'connect_link_deleted',
      outcome: 'SUCCESS',
      details: { title: existing.title },
    });
    res.status(204).send();
  } catch (err) {
    next(err);
  }
});
