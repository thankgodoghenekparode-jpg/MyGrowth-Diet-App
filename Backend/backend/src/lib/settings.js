import prisma from '../db/index.js';
import { errors } from './errors.js';

/**
 * Application settings stored in the `Setting` table (key/value JSON).
 * Defaults are defined here; admins can change allowed keys via /admin/settings.
 */
export const SETTING_DEFAULTS = {
  'registration.approvalRequired': false,
  'goals.maxMonthlySuggested': 3,
  'goals.allowExtra': false,
  'announcements.notifyOnPublish': true,
};

export const SETTING_KEYS = Object.keys(SETTING_DEFAULTS);

const cache = new Map();
let cacheAt = 0;
const CACHE_TTL_MS = 3000;

export async function getSetting(key) {
  if (!(key in SETTING_DEFAULTS)) {
    throw errors.badRequest(`Unknown setting: ${key}`, 'VALIDATION_ERROR');
  }
  const now = Date.now();
  if (now - cacheAt > CACHE_TTL_MS) {
    cache.clear();
    cacheAt = now;
  }
  if (cache.has(key)) return cache.get(key);
  const row = await prisma.setting.findUnique({ where: { key } });
  const value = row ? row.value : SETTING_DEFAULTS[key];
  cache.set(key, value);
  return value;
}

export async function getAllSettings() {
  const out = {};
  for (const key of SETTING_KEYS) out[key] = await getSetting(key);
  return out;
}

export async function setSetting(key, value, updatedBy = null) {
  if (!(key in SETTING_DEFAULTS)) {
    throw errors.badRequest(`Unknown setting: ${key}`, 'VALIDATION_ERROR');
  }
  const row = await prisma.setting.upsert({
    where: { key },
    create: { key, value, updatedBy },
    update: { value, updatedBy },
  });
  cache.set(key, row.value);
  return row.value;
}

export function clearSettingCache() {
  cache.clear();
  cacheAt = 0;
}
