import { Router } from 'express';
import { requireAuth, requireAdmin, requireMainAdmin } from '../../middleware/auth.js';
import { usersRouter, adminsRouter } from './users.routes.js';
import { contentRouter } from './content.routes.js';
import { adminPartnersRouter } from './prayerPartners.routes.js';
import { materialsRouter, filesRouter } from './materials.routes.js';
import { reportsRouter, safetyRouter } from './reports.routes.js';
import { analyticsRouter, auditRouter, settingsRouter } from './analytics.routes.js';
import { dailyDietRouter } from './dailyDiet.routes.js';

const router = Router();

// Every /api/v1/admin route requires authentication + granted admin access.
router.use(requireAuth, requireAdmin);

router.use(usersRouter); // /users, /users/:id/...
router.use(contentRouter); // programmes, plans, announcements, categories, events
router.use(dailyDietRouter); // /daily-diet/sections, /daily-diet/content
router.use(adminPartnersRouter); // /prayer-partnerships, /prayer-partner-requests
router.use(materialsRouter); // /materials
router.use(filesRouter); // /files (upload)
router.use(reportsRouter); // /reports + reviews
router.use(safetyRouter); // /safety-reports
router.use(analyticsRouter); // /analytics/*
router.use(auditRouter); // /audit-logs
router.use(settingsRouter); // /settings

// Administrator account management: Main Admin only.
router.use('/admins', requireMainAdmin, adminsRouter);

export default router;
