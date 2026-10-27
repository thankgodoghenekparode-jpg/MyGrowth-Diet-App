import rateLimit from 'express-rate-limit';
import config from '../config/index.js';

function limiter({ windowMs, max, message }) {
  return rateLimit({
    windowMs,
    max,
    standardHeaders: true,
    legacyHeaders: false,
    skip: () => config.isTest, // tests exercise logic, not throttling
    message: { error: { code: 'RATE_LIMITED', message } },
  });
}

/** General API limiter. */
export const globalLimiter = limiter({
  windowMs: 15 * 60 * 1000,
  max: 500,
  message: 'Too many requests, please try again later.',
});

/** Stricter limiter for authentication endpoints (brute-force protection). */
export const authLimiter = limiter({
  windowMs: 15 * 60 * 1000,
  max: 20,
  message: 'Too many authentication attempts, please try again later.',
});

/** Stricter limiter for file uploads. */
export const uploadLimiter = limiter({
  windowMs: 60 * 60 * 1000,
  max: 40,
  message: 'Too many uploads, please try again later.',
});

/** Stricter limiter for prayer-partner requests (abuse/spam protection). */
export const partnerRequestLimiter = limiter({
  windowMs: 60 * 60 * 1000,
  max: 30,
  message: 'Too many prayer partner requests, please try again later.',
});

/** Conversation endpoints can be abused to spam members or generate AI costs. */
export const shapeSpaceMessageLimiter = limiter({
  windowMs: 60 * 60 * 1000,
  max: 40,
  message: 'You have sent too many messages. Please try again later.',
});

export const aiAssistantLimiter = limiter({
  windowMs: 60 * 60 * 1000,
  max: 30,
  message: 'The assistant has reached its hourly limit. Please try again later.',
});

/** Password reset / verification request limiter. */
export const sensitiveAuthLimiter = limiter({
  windowMs: 60 * 60 * 1000,
  max: 10,
  message: 'Too many attempts, please try again later.',
});
