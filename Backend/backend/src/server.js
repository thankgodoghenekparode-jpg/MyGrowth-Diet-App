import 'dotenv/config';
import config from './config/index.js';
import { createApp } from './app.js';
import { logger } from './lib/logger.js';
import prisma from './db/index.js';

const app = createApp();

const server = app.listen(config.port, async () => {
  logger.info(`MyGrowth Diet App API listening on http://localhost:${config.port} (${config.env})`);
  try {
    await prisma.$queryRaw`SELECT 1`;
    logger.info('Database connection: OK');
  } catch (err) {
    logger.error('Database connection FAILED', err?.message);
  }
});

async function shutdown(signal) {
  logger.info(`${signal} received — shutting down`);
  server.close(() => {
    prisma.$disconnect().finally(() => process.exit(0));
  });
  setTimeout(() => process.exit(1), 10000).unref();
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('unhandledRejection', (reason) => {
  logger.error('Unhandled rejection:', reason instanceof Error ? reason.message : reason);
});

export default server;
