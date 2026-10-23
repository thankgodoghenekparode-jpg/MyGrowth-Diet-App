import { PrismaClient } from '@prisma/client';
import config from '../config/index.js';

const options = {
  log: ['warn', 'error'],
};

// Tests always run against TEST_DATABASE_URL, never the development database.
if (config.isTest && config.testDatabaseUrl) {
  options.datasourceUrl = config.testDatabaseUrl;
}

/** Shared Prisma client (one per process). */
export const prisma = new PrismaClient(options);

export default prisma;
