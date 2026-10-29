import { Router } from 'express';
import { z } from 'zod';
import prisma from '../../db/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { validate, uuidSchema } from '../../lib/validate.js';
import { shapeSpaceMessageLimiter } from '../../middleware/rateLimiters.js';

const router = Router();
const messageSchema = z.object({
  body: z.string().trim().min(1).max(2000),
  isAnonymous: z.boolean().optional(),
});
const toggleAnonymousSchema = z.object({
  isAnonymous: z.boolean(),
});
const reportSchema = z.object({
  reason: z.string().trim().min(3).max(100),
  details: z.string().trim().max(1000).optional(),
});

/**
 * GET /api/v1/shape-space/messages
 * Retrieves the member's private pastoral counselling conversation and message thread.
 */
router.get('/messages', asyncHandler(async (req, res) => {
  let conversation = await prisma.shapeSpaceConversation.findUnique({
    where: { memberId: req.user.id },
  });

  if (!conversation) {
    conversation = await prisma.shapeSpaceConversation.create({
      data: { memberId: req.user.id, isAnonymous: false },
    });
  }

  // Mark any unread pastor replies as read
  await prisma.shapeSpaceMessage.updateMany({
    where: {
      conversationId: conversation.id,
      isFromAdmin: true,
      readAt: null,
    },
    data: { readAt: new Date() },
  });

  const messages = await prisma.shapeSpaceMessage.findMany({
    where: { conversationId: conversation.id, hiddenAt: null },
    orderBy: { createdAt: 'asc' },
    select: {
      id: true,
      body: true,
      isFromAdmin: true,
      isAnonymous: true,
      readAt: true,
      createdAt: true,
      sender: {
        select: {
          id: true,
          firstName: true,
          lastName: true,
          role: true,
        },
      },
    },
  });

  res.json({
    conversation: {
      id: conversation.id,
      status: conversation.status,
      isAnonymous: conversation.isAnonymous,
      lastMessageAt: conversation.lastMessageAt,
    },
    messages: messages.map((m) => {
      const isMe = m.sender.id === req.user.id;
      return {
        id: m.id,
        body: m.body,
        isFromAdmin: m.isFromAdmin,
        isAnonymous: m.isAnonymous,
        readAt: m.readAt,
        createdAt: m.createdAt,
        own: isMe,
        senderName: m.isFromAdmin
          ? 'Pastor / Spiritual Counselor'
          : m.isAnonymous
          ? 'You (Anonymous)'
          : `${m.sender.firstName} ${m.sender.lastName}`.trim() || 'You',
        user: {
          id: m.sender.id,
          firstName: m.isFromAdmin ? 'Pastor' : m.isAnonymous ? 'You' : m.sender.firstName,
          lastName: m.isFromAdmin ? 'Counselor' : m.isAnonymous ? '(Anonymous)' : m.sender.lastName,
        },
      };
    }),
  });
}));

/**
 * POST /api/v1/shape-space/messages
 * Sends a message in the member's pastoral counselling thread.
 */
router.post('/messages', shapeSpaceMessageLimiter, validate({ body: messageSchema }), asyncHandler(async (req, res) => {
  let conversation = await prisma.shapeSpaceConversation.findUnique({
    where: { memberId: req.user.id },
  });

  const isAnon = req.valid.body.isAnonymous !== undefined
    ? req.valid.body.isAnonymous
    : (conversation ? conversation.isAnonymous : false);

  if (!conversation) {
    conversation = await prisma.shapeSpaceConversation.create({
      data: { memberId: req.user.id, isAnonymous: isAnon },
    });
  }

  const message = await prisma.shapeSpaceMessage.create({
    data: {
      conversationId: conversation.id,
      senderId: req.user.id,
      body: req.valid.body.body,
      isAnonymous: isAnon,
      isFromAdmin: false,
    },
    select: {
      id: true,
      body: true,
      isFromAdmin: true,
      isAnonymous: true,
      readAt: true,
      createdAt: true,
    },
  });

  await prisma.shapeSpaceConversation.update({
    where: { id: conversation.id },
    data: {
      lastMessageAt: new Date(),
      status: 'OPEN',
      isAnonymous: isAnon,
    },
  });

  res.status(201).json({
    message: {
      ...message,
      own: true,
      senderName: isAnon ? 'You (Anonymous)' : `${req.user.firstName} ${req.user.lastName}`.trim(),
    },
  });
}));

/**
 * POST /api/v1/shape-space/anonymity
 * Toggles the member's default anonymity preference for the counselling room.
 */
router.post('/anonymity', validate({ body: toggleAnonymousSchema }), asyncHandler(async (req, res) => {
  const conversation = await prisma.shapeSpaceConversation.upsert({
    where: { memberId: req.user.id },
    create: { memberId: req.user.id, isAnonymous: req.valid.body.isAnonymous },
    update: { isAnonymous: req.valid.body.isAnonymous },
  });

  res.json({ isAnonymous: conversation.isAnonymous });
}));

/**
 * POST /api/v1/shape-space/messages/:id/report
 * Flags an inappropriate message for safety review.
 */
router.post('/messages/:id/report', validate({
  params: z.object({ id: uuidSchema }),
  body: reportSchema,
}), asyncHandler(async (req, res) => {
  const message = await prisma.shapeSpaceMessage.findUnique({
    where: { id: req.valid.params.id },
    select: { id: true, senderId: true, body: true },
  });

  if (!message || message.senderId === req.user.id) {
    throw errors.notFound('Message not found');
  }

  const report = await prisma.safetyReport.create({
    data: {
      reporterId: req.user.id,
      reportedId: message.senderId,
      reason: `SHAPE_SPACE: ${req.valid.body.reason}`,
      details: [req.valid.body.details, `Message: ${message.body}`].filter(Boolean).join('\n'),
    },
  });

  res.status(201).json({ report: { id: report.id, status: report.status } });
}));

export default router;
