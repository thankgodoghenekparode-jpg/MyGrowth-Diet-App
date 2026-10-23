import { Router } from 'express';
import * as h from './auth.handlers.js';
import { requireAuth } from '../../middleware/auth.js';
import { authLimiter, sensitiveAuthLimiter } from '../../middleware/rateLimiters.js';
import { validate } from '../../lib/validate.js';
import { asyncHandler } from '../../lib/errors.js';
import { publicUser } from './auth.handlers.js';

const router = Router();

router.post('/register', authLimiter, ...h.register);
router.post('/login', authLimiter, ...h.login);
router.post('/refresh', authLimiter, h.refresh);
router.post('/logout', h.logout);
router.post('/forgot-password', sensitiveAuthLimiter, ...h.forgotPassword);
router.post('/reset-password', sensitiveAuthLimiter, ...h.resetPassword);
router.post('/verify-email', ...h.verifyEmail);
router.post('/resend-verification', sensitiveAuthLimiter, ...h.resendVerification);
router.post(
  '/change-password',
  requireAuth,
  authLimiter,
  ...h.changePassword
);
router.get(
  '/session',
  requireAuth,
  asyncHandler(async (req, res) => {
    res.json({ user: publicUser(req.user) });
  })
);

export default router;
