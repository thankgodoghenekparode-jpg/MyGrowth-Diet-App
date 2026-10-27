import { Router } from 'express';
import { z } from 'zod';
import prisma from '../../db/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { validate, uuidSchema } from '../../lib/validate.js';
import { shapeSpaceMessageLimiter } from '../../middleware/rateLimiters.js';

const router = Router();
const messageSchema = z.object({ body: z.string().trim().min(1).max(1000) });
const reportSchema = z.object({ reason: z.string().trim().min(3).max(100), details: z.string().trim().max(1000).optional() });
const messageSelect = {
  id: true, body: true, createdAt: true, hiddenAt: true,
  user: { select: { id: true, firstName: true, lastName: true } },
};

router.get('/messages', asyncHandler(async (_req, res) => {
  const rows = await prisma.shapeSpaceMessage.findMany({
    where: { hiddenAt: null }, orderBy: { createdAt: 'desc' }, take: 100,
    select: messageSelect,
  });
  res.json({ messages: rows.reverse() });
}));

router.post('/messages', shapeSpaceMessageLimiter, validate({ body: messageSchema }), asyncHandler(async (req, res) => {
  const message = await prisma.shapeSpaceMessage.create({
    data: { userId: req.user.id, body: req.valid.body.body },
    select: messageSelect,
  });
  res.status(201).json({ message });
}));

router.post('/messages/:id/report', validate({
  params: z.object({ id: uuidSchema }), body: reportSchema,
}), asyncHandler(async (req, res) => {
  const message = await prisma.shapeSpaceMessage.findUnique({
    where: { id: req.valid.params.id }, select: { id: true, userId: true, body: true },
  });
  if (!message || message.userId === req.user.id) throw errors.notFound('Message not found');
  const report = await prisma.safetyReport.create({
    data: {
      reporterId: req.user.id, reportedId: message.userId,
      reason: `SHAPE_SPACE: ${req.valid.body.reason}`,
      details: [req.valid.body.details, `Message: ${message.body}`].filter(Boolean).join('\n'),
    },
  });
  res.status(201).json({ report: { id: report.id, status: report.status } });
}));

export default router;
