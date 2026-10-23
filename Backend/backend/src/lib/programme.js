import prisma from '../db/index.js';
import { dateFromISO, isoDate } from './dates.js';

/**
 * Resolve the published programme covering a date (Africa/Lagos calendar date).
 * Falls back to the most recent published programme when the date lies outside
 * every published programme (e.g. the app is opened before the programme year)
 * so members still see the current ministry content; `dateInProgramme` tells
 * the caller whether the date actually falls inside the programme range.
 */
export async function resolveProgrammeForDate(dateISO) {
  const date = dateFromISO(dateISO);
  const inRange = await prisma.programme.findFirst({
    where: {
      status: 'PUBLISHED',
      OR: [
        { AND: [{ startDate: { lte: date } }, { endDate: { gte: date } }] },
        { AND: [{ startDate: { lte: date } }, { endDate: null }] },
      ],
    },
    orderBy: { year: 'desc' },
  });
  if (inRange) return { programme: inRange, dateInProgramme: true };
  const latest = await prisma.programme.findFirst({
    where: { status: 'PUBLISHED' },
    orderBy: { year: 'desc' },
  });
  return { programme: latest, dateInProgramme: false };
}

export async function resolveMonthlyPlan(programmeId, month, year) {
  if (!programmeId) return null;
  return prisma.monthlyPlan.findFirst({
    where: { programmeId, month, status: 'PUBLISHED' },
  });
}

/** Latest published programme (for dashboards / "current programme"). */
export async function latestPublishedProgramme() {
  return prisma.programme.findFirst({
    where: { status: 'PUBLISHED' },
    orderBy: { year: 'desc' },
  });
}

export function monthOf(dateISO) {
  return Number.parseInt(dateISO.slice(5, 7), 10);
}

export function yearOf(dateISO) {
  return Number.parseInt(dateISO.slice(0, 4), 10);
}

export { isoDate };
