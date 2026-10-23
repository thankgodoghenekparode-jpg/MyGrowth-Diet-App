import cron from 'node-cron';
import 'dotenv/config';
import { DateTime } from 'luxon';
import { runAllReminderTasks } from './tasks.js';
import { logger } from '../lib/logger.js';
import prisma from '../db/index.js';

/**
 * Standalone scheduler worker (npm run worker).
 * Runs the reminder task suite every minute (tasks are idempotent — dedup via
 * the (userId, eventType, eventKey) unique constraint) plus hourly housekeeping.
 * In production you may instead (or additionally) use POST /api/v1/cron/tick
 * with a platform cron service; see docs/DEPLOYMENT.md.
 */
let running = false;

async function tick() {
  if (running) return; // never overlap runs
  running = true;
  const started = Date.now();
  try {
    const results = await runAllReminderTasks(DateTime.now());
    logger.info(`worker tick completed in ${Date.now() - started}ms`, JSON.stringify(results));
  } catch (err) {
    logger.error('worker tick failed', err?.message);
  } finally {
    running = false;
  }
}

export function startWorker() {
  cron.schedule('* * * * *', tick, { timezone: 'Africa/Lagos' });
  logger.info('MyGrowth worker scheduled: reminder tasks every minute (Africa/Lagos)');
  return { tick };
}

// Entrypoint
if (import.meta.url === `file:///${process.argv[1].replace(/\\/g, '/')}` || process.argv[1]?.endsWith('worker.js')) {
  startWorker();
  // Run once shortly after boot so a fresh deployment starts producing reminders.
  setTimeout(tick, 5000);

  const shutdown = async () => {
    logger.info('worker shutting down');
    await prisma.$disconnect();
    process.exit(0);
  };
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}
