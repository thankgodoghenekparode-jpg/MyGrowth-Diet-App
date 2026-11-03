import { Router } from 'express';
import { z } from 'zod';
import prisma from '../../db/index.js';
import { asyncHandler, errors } from '../../lib/errors.js';
import { validate, uuidSchema } from '../../lib/validate.js';
import { shapeSpaceMessageLimiter } from '../../middleware/rateLimiters.js';

const router = Router();
const postSchema = z.object({
  body: z.string().trim().min(1).max(2000),
  isAnonymous: z.boolean().optional().default(false),
});
const reportSchema = z.object({
  reason: z.string().trim().min(3).max(100),
  details: z.string().trim().max(1000).optional(),
});

const nameOf = (user, anonymous) => anonymous
  ? 'Anonymous Member'
  : `${user.firstName} ${user.lastName}`.trim() || 'Member';

/** List public questions and their answer counts for the community feed. */
router.get('/questions', asyncHandler(async (req, res) => {
  const questions = await prisma.shapeSpaceConversation.findMany({
    where: { isCommunity: true, status: { not: 'ARCHIVED' } },
    orderBy: { lastMessageAt: 'desc' },
    include: {
      member: { select: { firstName: true, lastName: true } },
      messages: {
        where: { hiddenAt: null },
        orderBy: { createdAt: 'asc' },
        take: 1,
        select: {
          id: true,
          senderId: true,
          body: true,
          isAnonymous: true,
          createdAt: true,
          sender: { select: { firstName: true, lastName: true } },
        },
      },
      _count: { select: { messages: true } },
    },
  });

  res.json({
    questions: questions
      .filter((thread) => thread.messages.length > 0)
      .map((thread) => {
        const question = thread.messages[0];
        return {
          id: thread.id,
          messageId: question.id,
          body: question.body,
          authorName: nameOf(question.sender, question.isAnonymous),
          isAnonymous: question.isAnonymous,
          createdAt: question.createdAt,
          answerCount: Math.max(0, thread._count.messages - 1),
          own: question.senderId === req.user.id,
          lastMessageAt: thread.lastMessageAt,
          status: thread.status,
        };
      }),
  });
}));

/** Read one public question with its visible answers. */
router.get('/questions/:id', validate({ params: z.object({ id: uuidSchema }) }), asyncHandler(async (req, res) => {
  const thread = await prisma.shapeSpaceConversation.findFirst({
    where: { id: req.valid.params.id, isCommunity: true, status: { not: 'ARCHIVED' } },
    include: {
      messages: {
        where: { hiddenAt: null },
        orderBy: { createdAt: 'asc' },
        select: {
          id: true,
          body: true,
          isAnonymous: true,
          createdAt: true,
          senderId: true,
          sender: { select: { firstName: true, lastName: true } },
        },
      },
    },
  });
  if (!thread || thread.messages.length === 0) throw errors.notFound('Question not found');

  const [question, ...answers] = thread.messages;
  res.json({
    question: {
      id: thread.id,
      messageId: question.id,
      body: question.body,
      authorName: nameOf(question.sender, question.isAnonymous),
      isAnonymous: question.isAnonymous,
      createdAt: question.createdAt,
      own: question.senderId === req.user.id,
      status: thread.status,
    },
    answers: answers.map((answer) => ({
      id: answer.id,
      body: answer.body,
      authorName: nameOf(answer.sender, answer.isAnonymous),
      isAnonymous: answer.isAnonymous,
      createdAt: answer.createdAt,
      own: answer.senderId === req.user.id,
    })),
  });
}));

/** Create a public question. The first message in each thread is its question. */
router.post('/questions', shapeSpaceMessageLimiter, validate({ body: postSchema }), asyncHandler(async (req, res) => {
  const { body, isAnonymous } = req.valid.body;
  const thread = await prisma.$transaction(async (tx) => {
    const createdThread = await tx.shapeSpaceConversation.create({
      data: {
        memberId: req.user.id,
        isAnonymous,
        isCommunity: true,
      },
    });
    const question = await tx.shapeSpaceMessage.create({
      data: {
        conversationId: createdThread.id,
        senderId: req.user.id,
        body,
        isAnonymous,
      },
      select: { id: true, body: true, isAnonymous: true, createdAt: true },
    });
    return { createdThread, question };
  });

  res.status(201).json({
    question: {
      id: thread.createdThread.id,
      body: thread.question.body,
      authorName: nameOf(req.user, thread.question.isAnonymous),
      isAnonymous: thread.question.isAnonymous,
      createdAt: thread.question.createdAt,
      answerCount: 0,
      lastMessageAt: thread.createdThread.lastMessageAt,
      status: thread.createdThread.status,
    },
  });
}));

/** Add a public answer to any question in the community. */
router.post('/questions/:id/answers', shapeSpaceMessageLimiter, validate({
  params: z.object({ id: uuidSchema }),
  body: postSchema,
}), asyncHandler(async (req, res) => {
  const thread = await prisma.shapeSpaceConversation.findFirst({
    where: { id: req.valid.params.id, isCommunity: true, status: { not: 'ARCHIVED' } },
    select: { id: true },
  });
  if (!thread) throw errors.notFound('Question not found');

  const answer = await prisma.$transaction(async (tx) => {
    const created = await tx.shapeSpaceMessage.create({
      data: {
        conversationId: thread.id,
        senderId: req.user.id,
        body: req.valid.body.body,
        isAnonymous: req.valid.body.isAnonymous,
      },
      select: { id: true, body: true, isAnonymous: true, createdAt: true },
    });
    await tx.shapeSpaceConversation.update({
      where: { id: thread.id },
      data: { lastMessageAt: created.createdAt },
    });
    return created;
  });

  res.status(201).json({
    answer: {
      ...answer,
      authorName: nameOf(req.user, answer.isAnonymous),
      own: true,
    },
  });
}));

/** Report a community question or answer for admin review. */
router.post('/messages/:id/report', validate({
  params: z.object({ id: uuidSchema }),
  body: reportSchema,
}), asyncHandler(async (req, res) => {
  const message = await prisma.shapeSpaceMessage.findFirst({
    where: {
      id: req.valid.params.id,
      conversation: { isCommunity: true },
    },
    select: { id: true, senderId: true, body: true },
  });

  if (!message || message.senderId === req.user.id) throw errors.notFound('Post not found');

  const report = await prisma.safetyReport.create({
    data: {
      reporterId: req.user.id,
      reportedId: message.senderId,
      reason: `SHAPE_SPACE: ${req.valid.body.reason}`,
      details: [req.valid.body.details, `Post: ${message.body}`].filter(Boolean).join('\n'),
    },
  });
  res.status(201).json({ report: { id: report.id, status: report.status } });
}));

export default router;
