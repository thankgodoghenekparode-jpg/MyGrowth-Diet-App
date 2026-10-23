import { Router } from 'express';
import prisma from '../../db/index.js';
import { asyncHandler } from '../../lib/errors.js';
import { runAllReminderTasks } from '../../jobs/tasks.js';
import { errors } from '../../lib/errors.js';
import config from '../../config/index.js';
import { timingSafeEqual } from 'node:crypto';

const router = Router();

/** GET /api/v1/health — liveness/readiness probe (includes a DB check). */
export async function healthHandler(req, res) {
  let db = 'up';
  try {
    await prisma.$queryRaw`SELECT 1`;
  } catch {
    db = 'down';
  }
  res.status(db === 'up' ? 200 : 503).json({
    status: db === 'up' ? 'ok' : 'degraded',
    service: 'mygrowth-diet-app-backend',
    env: config.env,
    db,
    uptimeSeconds: Math.round(process.uptime()),
    timestamp: new Date().toISOString(),
  });
}

function secretMatches(provided) {
  if (!config.cronSecret || !provided) return false;
  const a = Buffer.from(String(provided));
  const b = Buffer.from(config.cronSecret);
  if (a.length !== b.length) return false;
  return timingSafeEqual(a, b);
}

/**
 * POST /api/v1/cron/tick — protected endpoint for platform schedulers
 * (Render cron jobs, GitHub Actions, cron.li, etc.) that cannot run the
 * bundled node-cron worker. Requires header `x-cron-secret: CRON_SECRET`.
 */
router.post(
  '/tick',
  asyncHandler(async (req, res) => {
    const provided = req.get('x-cron-secret') || req.body?.secret;
    if (!secretMatches(provided)) {
      throw errors.forbidden('Invalid cron secret', 'CRON_SECRET_INVALID');
    }
    const results = await runAllReminderTasks();
    res.json({ ok: true, results, ranAt: new Date().toISOString() });
  })
);

export default router;
