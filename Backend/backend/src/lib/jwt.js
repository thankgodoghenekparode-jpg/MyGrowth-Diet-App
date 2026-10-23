import jwt from 'jsonwebtoken';
import crypto from 'node:crypto';
import config from '../config/index.js';

export function signAccessToken(user) {
  return jwt.sign(
    {
      sub: user.id,
      role: user.role,
      typ: 'access',
    },
    config.jwt.accessSecret,
    { expiresIn: config.jwt.accessTtl }
  );
}

export function signRefreshToken(user, tokenId) {
  return jwt.sign(
    { sub: user.id, typ: 'refresh', jti: tokenId },
    config.jwt.refreshSecret,
    { expiresIn: `${config.jwt.refreshTtlDays}d` }
  );
}

export function verifyAccessToken(token) {
  return jwt.verify(token, config.jwt.accessSecret);
}

export function verifyRefreshToken(token) {
  return jwt.verify(token, config.jwt.refreshSecret);
}

/** SHA-256 hash used to store refresh/reset/verification tokens at rest. */
export function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

export function randomToken() {
  return crypto.randomBytes(32).toString('hex');
}

export const ACCESS_TOKEN_TTL_SECONDS = 15 * 60;
