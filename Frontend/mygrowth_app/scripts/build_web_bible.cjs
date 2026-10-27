// Build a compact, offline Bible asset from eBible.org's VPL archive.
// Download the matching archive into assets/bible/, then run:
// node scripts/build_web_bible.cjs [web|bsb|kjv]
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const appRoot = path.resolve(__dirname, '..');
const versions = {
  web: { archive: 'engwebp_vpl.zip', file: 'engwebp_vpl.txt', name: 'World English Bible', abbreviation: 'WEB' },
  bsb: { archive: 'engbsb_vpl.zip', file: 'engbsb_vpl.txt', name: 'Berean Standard Bible', abbreviation: 'BSB' },
  kjv: { archive: 'eng-kjv2006_vpl.zip', file: 'eng-kjv2006_vpl.txt', name: 'King James Version', abbreviation: 'KJV' },
};
const versionId = (process.argv[2] || 'web').toLowerCase();
const version = versions[versionId];
if (!version) throw new Error(`Unknown Bible version: ${versionId}`);
const archive = path.join(appRoot, 'assets/bible', version.archive);
const tar = process.platform === 'win32' ? 'tar.exe' : 'tar';
const source = execFileSync(tar, ['-xOf', archive, version.file], {
  encoding: 'utf8',
  maxBuffer: 16 * 1024 * 1024,
});

const books = [
  ['GEN', 'Genesis'], ['EXO', 'Exodus'], ['LEV', 'Leviticus'],
  ['NUM', 'Numbers'], ['DEU', 'Deuteronomy'], ['JOS', 'Joshua'],
  ['JDG', 'Judges'], ['RUT', 'Ruth'], ['1SA', '1 Samuel'],
  ['2SA', '2 Samuel'], ['1KI', '1 Kings'], ['2KI', '2 Kings'],
  ['1CH', '1 Chronicles'], ['2CH', '2 Chronicles'], ['EZR', 'Ezra'],
  ['NEH', 'Nehemiah'], ['EST', 'Esther'], ['JOB', 'Job'],
  ['PSA', 'Psalms'], ['PRO', 'Proverbs'], ['ECC', 'Ecclesiastes'],
  ['SOL', 'Song of Solomon'], ['ISA', 'Isaiah'], ['JER', 'Jeremiah'],
  ['LAM', 'Lamentations'], ['EZE', 'Ezekiel'], ['DAN', 'Daniel'],
  ['HOS', 'Hosea'], ['JOE', 'Joel'], ['AMO', 'Amos'], ['OBA', 'Obadiah'],
  ['JON', 'Jonah'], ['MIC', 'Micah'], ['NAH', 'Nahum'], ['HAB', 'Habakkuk'],
  ['ZEP', 'Zephaniah'], ['HAG', 'Haggai'], ['ZEC', 'Zechariah'],
  ['MAL', 'Malachi'], ['MAT', 'Matthew'], ['MAR', 'Mark'], ['LUK', 'Luke'],
  ['JOH', 'John'], ['ACT', 'Acts'], ['ROM', 'Romans'],
  ['1CO', '1 Corinthians'], ['2CO', '2 Corinthians'], ['GAL', 'Galatians'],
  ['EPH', 'Ephesians'], ['PHI', 'Philippians'], ['COL', 'Colossians'],
  ['1TH', '1 Thessalonians'], ['2TH', '2 Thessalonians'],
  ['1TI', '1 Timothy'], ['2TI', '2 Timothy'], ['TIT', 'Titus'],
  ['PHM', 'Philemon'], ['HEB', 'Hebrews'], ['JAM', 'James'],
  ['1PE', '1 Peter'], ['2PE', '2 Peter'], ['1JO', '1 John'],
  ['2JO', '2 John'], ['3JO', '3 John'], ['JUD', 'Jude'], ['REV', 'Revelation'],
].map(([code, name]) => ({ code, name, chapters: [] }));

const byCode = new Map(books.map((book) => [book.code, book]));
let parsed = 0;
for (const line of source.split(/\r?\n/)) {
  const match = line.match(/^([A-Z0-9]{3})\s+(\d+):(\d+)\s+(.*)$/);
  if (!match) continue;
  const [, code, chapterText, verseText, text] = match;
  const book = byCode.get(code);
  if (!book) throw new Error(`Unknown book code in source: ${code}`);
  const chapter = Number(chapterText) - 1;
  const verse = Number(verseText) - 1;
  book.chapters[chapter] ??= [];
  const verses = book.chapters[chapter];
  while (verses.length <= verse) verses.push(null);
  verses[verse] = verses[verse] ? `${verses[verse]} ${text}` : text;
  parsed += 1;
}

if (parsed < 30000 || books.some((book) => book.chapters.length === 0)) {
  throw new Error(`Bible source appears incomplete (${parsed} verse rows).`);
}

const output = {
  translation: version.name,
  abbreviation: version.abbreviation,
  source: `https://ebible.org/${versionId === 'kjv' ? 'eng-kjv2006' : `eng${versionId}`}/`,
  books,
};
const destination = path.join(appRoot, `assets/bible/${versionId}.json`);
fs.writeFileSync(destination, JSON.stringify(output), 'utf8');
console.log(`Wrote ${parsed} verse rows across ${books.length} books to ${destination}`);
