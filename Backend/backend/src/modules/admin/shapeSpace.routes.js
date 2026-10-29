import { Router } from 'express';
import { z } from 'zod';
import prisma from '../../db/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { validate, uuidSchema } from '../../lib/validate.js';

export const adminShapeSpaceRouter = Router();

const replySchema = z.object({
  body: z.string().trim().min(1).max(2000),
});

const statusSchema = z.object({
  status: z.enum(['OPEN', 'RESOLVED', 'ARCHIVED']),
});

/**
 * GET /api/v1/admin/shape-space/conversations
 * Lists all member counselling threads for pastoral care.
 */
adminShapeSpaceRouter.get('/conversations', asyncHandler(async (_req, res) => {
  const conversations = await prisma.shapeSpaceConversation.findMany({
    orderBy: { lastMessageAt: 'desc' },
    include: {
      member: {
        select: {
          id: true,
          firstName: true,
          lastName: true,
          email: true,
        },
      },
      messages: {
        orderBy: { createdAt: 'desc' },
        take: 1,
        select: {
          id: true,
          body: true,
          isAnonymous: true,
          isFromAdmin: true,
          createdAt: true,
        },
      },
    },
  });

  const unreadCounts = await prisma.shapeSpaceMessage.groupBy({
    by: ['conversationId'],
    where: {
      isFromAdmin: false,
      readAt: null,
      hiddenAt: null,
    },
    _count: { id: true },
  });

  const unreadMap = new Map(unreadCounts.map((u) => [u.conversationId, u._count.id]));

  const result = conversations.map((conv) => {
    const lastMsg = conv.messages[0];
    const isAnonymous = conv.isAnonymous || (lastMsg && lastMsg.isAnonymous);

    return {
      id: conv.id,
      memberId: conv.memberId,
      status: conv.status,
      isAnonymous: Boolean(isAnonymous),
      memberName: isAnonymous
        ? `Anonymous Member (${conv.id.slice(0, 6).toUpperCase()})`
        : `${conv.member.firstName} ${conv.member.lastName}`.trim(),
      memberEmail: isAnonymous ? null : conv.member.email,
      lastMessage: lastMsg
        ? {
            id: lastMsg.id,
            body: lastMsg.body,
            isFromAdmin: lastMsg.isFromAdmin,
            createdAt: lastMsg.createdAt,
          }
        : null,
      lastMessageAt: conv.lastMessageAt,
      unreadCount: unreadMap.get(conv.id) || 0,
      createdAt: conv.createdAt,
    };
  });

  res.json({ conversations: result });
}));

/**
 * GET /api/v1/admin/shape-space/conversations/:id
 * Retrieves the full pastoral counselling thread for a conversation.
 */
adminShapeSpaceRouter.get('/conversations/:id', validate({
  params: z.object({ id: uuidSchema }),
}), asyncHandler(async (req, res) => {
  const conversation = await prisma.shapeSpaceConversation.findUnique({
    where: { id: req.valid.params.id },
    include: {
      member: {
        select: {
          id: true,
          firstName: true,
          lastName: true,
          email: true,
        },
      },
    },
  });

  if (!conversation) {
    throw errors.notFound('Pastoral counselling conversation not found');
  }

  // Mark member messages as read by pastor/admin
  await prisma.shapeSpaceMessage.updateMany({
    where: {
      conversationId: conversation.id,
      isFromAdmin: false,
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
      isAnonymous: true,
      isFromAdmin: true,
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

  const isAnonymous = conversation.isAnonymous;

  res.json({
    conversation: {
      id: conversation.id,
      status: conversation.status,
      isAnonymous,
      memberName: isAnonymous
        ? `Anonymous Member (${conversation.id.slice(0, 6).toUpperCase()})`
        : `${conversation.member.firstName} ${conversation.member.lastName}`.trim(),
      memberEmail: isAnonymous ? null : conversation.member.email,
      lastMessageAt: conversation.lastMessageAt,
      createdAt: conversation.createdAt,
    },
    messages: messages.map((m) => ({
      id: m.id,
      body: m.body,
      isFromAdmin: m.isFromAdmin,
      isAnonymous: m.isAnonymous,
      readAt: m.readAt,
      createdAt: m.createdAt,
      senderName: m.isFromAdmin
        ? 'Pastor (You)'
        : m.isAnonymous
        ? 'Anonymous Member'
        : `${m.sender.firstName} ${m.sender.lastName}`.trim(),
    })),
  });
}));

/**
 * POST /api/v1/admin/shape-space/conversations/:id/reply
 * Pastor sends a reply to a member's counselling thread.
 */
adminShapeSpaceRouter.post('/conversations/:id/reply', validate({
  params: z.object({ id: uuidSchema }),
  body: replySchema,
}), asyncHandler(async (req, res) => {
  const conversation = await prisma.shapeSpaceConversation.findUnique({
    where: { id: req.valid.params.id },
  });

  if (!conversation) {
    throw errors.notFound('Pastoral counselling conversation not found');
  }

  const message = await prisma.shapeSpaceMessage.create({
    data: {
      conversationId: conversation.id,
      senderId: req.user.id,
      body: req.valid.body.body,
      isAnonymous: false,
      isFromAdmin: true,
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
    data: { lastMessageAt: new Date(), status: 'OPEN' },
  });

  res.status(201).json({
    message: {
      ...message,
      senderName: 'Pastor (You)',
    },
  });
}));

/**
 * PATCH /api/v1/admin/shape-space/conversations/:id/status
 * Updates the conversation status (e.g. RESOLVED or OPEN).
 */
adminShapeSpaceRouter.patch('/conversations/:id/status', validate({
  params: z.object({ id: uuidSchema }),
  body: statusSchema,
}), asyncHandler(async (req, res) => {
  const updated = await prisma.shapeSpaceConversation.update({
    where: { id: req.valid.params.id },
    data: { status: req.valid.body.status },
    select: { id: true, status: true, updatedAt: true },
  });

  res.json({ conversation: updated });
}));
