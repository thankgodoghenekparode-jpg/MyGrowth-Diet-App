import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { SCRIPTURE_READING_2027 } from '../Backend/backend/prisma/data/scriptureReading2027.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const xmlPath = path.join(__dirname, 'document.xml');
if (!fs.existsSync(xmlPath)) {
  console.error('document.xml not found at', xmlPath);
  process.exit(1);
}

const xml = fs.readFileSync(xmlPath, 'utf8');

// Match paragraphs
const pRegex = /<w:p\b[^>]*>([\s\S]*?)<\/w:p>/g;
let match;
const paragraphs = [];
while ((match = pRegex.exec(xml)) !== null) {
  const pContent = match[1];
  const tRegex = /<w:t[^>]*>([\s\S]*?)<\/w:t>/g;
  let tMatch;
  let text = '';
  while ((tMatch = tRegex.exec(pContent)) !== null) {
    text += tMatch[1];
  }
  text = text.trim();
  if (text.length > 0) {
    paragraphs.push(text);
  }
}

const dayRegex = /^Day\s+(\d+)\s*[\u2010-\u2015\-\:\.\—\–]\s*(.+)$/i;
const rawEntries = [];
let current = null;

for (const p of paragraphs) {
  const dm = p.match(dayRegex);
  if (dm) {
    if (current) rawEntries.push(current);
    current = {
      dayOfYear: parseInt(dm[1], 10),
      title: dm[2].trim(),
      body: []
    };
  } else if (current) {
    current.body.push(p);
  }
}
if (current) rawEntries.push(current);

console.log(`Parsed ${rawEntries.length} raw daily entries from document.xml.`);

// Month days in standard year
const monthDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

function getMonthAndDay(dayOfYear) {
  let rem = dayOfYear;
  for (let m = 0; m < 12; m++) {
    const daysInM = monthDays[m];
    if (rem <= daysInM) {
      return { month: m + 1, day: rem };
    }
    rem -= daysInM;
  }
  return { month: 12, day: 31 };
}

function deriveAnchorScripture(reading) {
  if (!reading) return 'Colossians 3:16';
  const clean = reading.trim();
  if (/^review/i.test(clean) || /^reflect/i.test(clean)) {
    if (/matthew/i.test(clean)) return 'Matthew 5:1-12';
    if (/mark/i.test(clean)) return 'Mark 1:14-15';
    if (/luke/i.test(clean)) return 'Luke 4:18-19';
    if (/john/i.test(clean)) return 'John 1:1-14';
    if (/acts/i.test(clean)) return 'Acts 1:8';
    if (/romans/i.test(clean)) return 'Romans 8:1-2';
    if (/corinthians/i.test(clean)) return '1 Corinthians 13:1-13';
    if (/galatians/i.test(clean)) return 'Galatians 5:22-25';
    if (/ephesians/i.test(clean)) return 'Ephesians 1:3-7';
    if (/philippians/i.test(clean)) return 'Philippians 4:4-8';
    if (/colossians/i.test(clean)) return 'Colossians 3:1-4';
    if (/thessalonians/i.test(clean)) return '1 Thessalonians 5:16-18';
    if (/timothy/i.test(clean)) return '2 Timothy 3:16-17';
    if (/hebrews/i.test(clean)) return 'Hebrews 12:1-2';
    if (/james/i.test(clean)) return 'James 1:22-25';
    if (/peter/i.test(clean)) return '1 Peter 2:9-10';
    if (/revelation/i.test(clean)) return 'Revelation 21:1-4';
    return 'Hebrews 4:12';
  }
  // Take first part before semicolon or comma or hyphen
  const match = clean.match(/^([1-3]?\s*[A-Za-z]+)\s*(\d+)/);
  if (match) {
    return `${match[1]} ${match[2]}:1-3`;
  }
  return clean;
}

const devotions = rawEntries.map((e) => {
  const { month, day } = getMonthAndDay(e.dayOfYear);
  const readingObj = SCRIPTURE_READING_2027[month - 1];
  const scriptureReading = readingObj && readingObj.readings[day - 1]
    ? readingObj.readings[day - 1]
    : '2 Peter 3:18';
  const anchorScripture = deriveAnchorScripture(scriptureReading);
  const content = e.body.join('\n\n');
  const confession = content;
  const prayer = `Heavenly Father, I thank You for Your truth today. Grant me the grace, wisdom, and strength to walk in the reality of this confession: "${e.title}". Let Your Word take deep root in my heart, bearing intentional and lasting fruit for Your glory, in Jesus' name. Amen.`;
  const thoughtForTheDay = `${e.title} — Be intentional in responding to God's Word with daily obedience, prayer, and faith.`;

  return {
    dayOfYear: e.dayOfYear,
    month,
    day,
    title: e.title,
    anchorScripture,
    scriptureReading,
    scriptureText: null,
    content,
    confession,
    prayer,
    thoughtForTheDay,
    author: 'Pastor Healings E. Azuike',
  };
});

// Ensure all 365 days exist
console.log(`Generated ${devotions.length} structured daily devotions.`);

// Write to Frontend assets
const frontendOut = path.join(__dirname, '..', 'Frontend', 'mygrowth_app', 'assets', 'devotions.json');
fs.writeFileSync(frontendOut, JSON.stringify(devotions, null, 2), 'utf8');
console.log(`Wrote JSON to ${frontendOut}`);

// Write to Backend prisma data
const backendOut = path.join(__dirname, '..', 'Backend', 'backend', 'prisma', 'data', 'devotions365.json');
fs.writeFileSync(backendOut, JSON.stringify(devotions, null, 2), 'utf8');
console.log(`Wrote JSON to ${backendOut}`);
