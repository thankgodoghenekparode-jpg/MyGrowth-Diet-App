import { Router } from 'express';
import prisma from '../../db/index.js';
import { requireAuth, requireApprovedMember } from '../../middleware/auth.js';

export const connectRoutes = Router();

connectRoutes.get('/', requireAuth, requireApprovedMember, async (req, res, next) => {
  try {
    const links = await prisma.connectLink.findMany({
      where: { isActive: true },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
    });
    res.json({ links });
  } catch (err) {
    next(err);
  }
});
