import { DateTime } from 'luxon';

export const DEFAULT_TIMEZONE = 'Africa/Lagos';

export function tz(user) {
  return user?.timezone || DEFAULT_TIMEZONE;
}

/** Week key: the Sunday that starts the containing week, in the given timezone. */
export function weekKey(dateLike, timezone = DEFAULT_TIMEZONE) {
  const dt = DateTime.fromISO(String(dateLike), { zone: timezone });
  const start = dt.minus({ days: dt.weekday % 7 }); // luxon weekday: 1=Mon..7=Sun
  return start.toFormat('yyyy-MM-dd');
}

export function monthKey(dateLike, timezone = DEFAULT_TIMEZONE) {
  return DateTime.fromISO(String(dateLike), { zone: timezone }).toFormat('yyyy-MM');
}

export function quarterKey(dateLike, timezone = DEFAULT_TIMEZONE) {
  const dt = DateTime.fromISO(String(dateLike), { zone: timezone });
  const q = Math.ceil(dt.month / 3);
  return `${dt.year}-Q${q}`;
}

export function yearKey(dateLike, timezone = DEFAULT_TIMEZONE) {
  return DateTime.fromISO(String(dateLike), { zone: timezone }).toFormat('yyyy');
}

/** Previous quarter key relative to a date (used by quarterly reminders). */
export function previousQuarterKey(dateLike, timezone = DEFAULT_TIMEZONE) {
  const dt = DateTime.fromISO(String(dateLike), { zone: timezone });
  let year = dt.year;
  let q = Math.ceil(dt.month / 3) - 1;
  if (q === 0) {
    q = 4;
    year -= 1;
  }
  return `${year}-Q${q}`;
}

export function nowInZone(timezone = DEFAULT_TIMEZONE) {
  return DateTime.now().setZone(timezone);
}

/** Parse a stored DB Date (midnight UTC) as a yyyy-MM-dd string. */
export function isoDate(date) {
  const dt = DateTime.fromJSDate(date, { zone: 'utc' });
  return dt.toFormat('yyyy-MM-dd');
}

/** Parse "YYYY-MM-DD" into a JS Date at midnight UTC (for Prisma @db.Date). */
export function dateFromISO(value) {
  return DateTime.fromISO(value, { zone: 'utc' }).toJSDate();
}

export function isValidTimeRange(range) {
  if (!range || typeof range !== 'object') return false;
  const re = /^([01]\d|2[0-3]):[0-5]\d$/;
  return re.test(String(range.start)) && re.test(String(range.end)) && range.start < range.end;
}
