import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import cookieParser from 'cookie-parser';
import config from './config/index.js';
import { logger } from './lib/logger.js';
import { notFoundHandler, errorHandler } from './middleware/error.js';
import { globalLimiter, authLimiter } from './middleware/rateLimiters.js';
import { requireAuth, requireApprovedMember } from './middleware/auth.js';

import authRoutes from './modules/auth/routes.js';
import meProfileRoutes from './modules/me/profile.routes.js';
import meActivityRoutes from './modules/me/activities.routes.js';
import meGoalRoutes from './modules/me/goals.routes.js';
import meDashboardRoutes from './modules/me/dashboard.routes.js';
import reportsRoutes from './modules/reports/reports.routes.js';
import reflectionsRoutes from './modules/reflections/reflections.routes.js';
import notificationsRoutes from './modules/notifications/notifications.routes.js';
import prayerPartnersRoutes from './modules/prayerPartners/prayerPartners.routes.js';
import programmesRoutes from './modules/programmes/programmes.routes.js';
import dailyDietRoutes from './modules/dailyDiet/dailyDiet.routes.js';
import materialsRoutes from './modules/materials/materials.routes.js';
import announcementsRoutes from './modules/announcements/announcements.routes.js';
import filesRoutes from './modules/files/files.routes.js';
import adminRoutes from './modules/admin/index.js';
import cronRoutes, { healthHandler } from './modules/cron/cron.routes.js';

export function createApp() {
  const app = express();

  app.set('trust proxy', 1);
  app.disable('x-powered-by');

  // API responses are authenticated, per-user JSON: never cache them.
  // Without this, browsers revalidate with If-None-Match and can serve a
  // bodiless 304 that breaks session restore on cold start.
  app.disable('etag');
  app.use((req, res, next) => {
    res.set('Cache-Control', 'no-store');
    next();
  });

  // Security headers
  app.use(
    helmet({
      crossOriginResourcePolicy: { policy: 'cross-origin' },
      contentSecurityPolicy: false, // API serves JSON; Flutter web is the client
    })
  );

  // CORS — allowlisted origins only, credentials enabled for the refresh cookie
  app.use(
    cors({
      origin(origin, cb) {
        if (!origin || config.corsOrigins.includes(origin)) return cb(null, true);
        return cb(new Error('CORS origin not allowed'));
      },
      credentials: true,
      methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization', 'X-Cron-Secret'],
      maxAge: 600,
    })
  );

  app.use(cookieParser());
  app.use(express.json({ limit: '1mb' }));
  app.use(express.urlencoded({ extended: false, limit: '1mb' }));
  app.use(globalLimiter);

  // Request log (method/path only — never bodies, tokens or query secrets)
  app.use((req, res, next) => {
    res.on('finish', () => {
      if (config.env !== 'test') {
        logger.info(`${req.method} ${req.originalUrl} -> ${res.statusCode}`);
      }
    });
    next();
  });

  // Health (public)
  app.get('/api/v1/health', healthHandler);
  app.get('/health', healthHandler);

  // Auth (stricter rate limits)
  app.use('/api/v1/auth', authRoutes);

  // Cron tick (secret-guarded)
  app.use('/api/v1/cron', cronRoutes);

  // Authenticated member context
  app.use('/api/v1/me', requireAuth, meProfileRoutes, meActivityRoutes, meGoalRoutes, meDashboardRoutes, reportsRoutes, reflectionsRoutes, notificationsRoutes);

  // Published content for members (approved only)
  app.use('/api/v1/programmes', requireAuth, requireApprovedMember, programmesRoutes);
  app.use('/api/v1/daily-diet', requireAuth, requireApprovedMember, dailyDietRoutes);
  app.use('/api/v1/materials', requireAuth, requireApprovedMember, materialsRoutes);
  app.use('/api/v1/announcements', requireAuth, requireApprovedMember, announcementsRoutes);

  // Prayer partners (any authenticated, approved member)
  app.use('/api/v1/prayer-partners', requireAuth, requireApprovedMember, prayerPartnersRoutes);

  // Authenticated file access
  app.use('/api/v1/files', requireAuth, filesRoutes);

  // Admin area
  app.use('/api/v1/admin', adminRoutes);

  // Member "me" content sub-routers that also need approved status are
  // handled inside their handlers; drafts of programme content are never
  // returned to members.

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}

export default createApp;
