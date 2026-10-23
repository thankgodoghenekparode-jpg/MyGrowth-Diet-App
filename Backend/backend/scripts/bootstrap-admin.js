/**
 * One-time, safe Main Admin bootstrap.
 *
 * Creates the single MAIN_ADMIN account for the application. The Main Admin is
 * the only account that can manage administrative access, and exactly one may
 * ever exist (enforced here with a serializable transaction + a database-level
 * guard, and by the absence of any API route that can create another).
 *
 * Usage:
 *   npm run bootstrap:admin -- --email admin@example.org --password "..." \
 *       [--first-name Ada] [--last-name Obi]
 *
 * Or via environment variables: ADMIN_EMAIL, ADMIN_PASSWORD,
 * ADMIN_FIRST_NAME, ADMIN_LAST_NAME.
 *
 * If no password is supplied, a strong random password is generated and shown
 * once. Never hardcode a production password.
 */
import 'dotenv/config';
import { randomBytes } from 'node:crypto';
import prisma from '../src/db/index.js';
import config from '../src/config/index.js';
import { hashPassword } from '../src/lib/password.js';
import { audit } from '../src/lib/audit.js';

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (!arg.startsWith('--')) continue;
    const key = arg.slice(2);
    const next = argv[i + 1];
    if (next && !next.startsWith('--')) {
      out[key] = next;
      i += 1;
    } else {
      out[key] = true;
    }
  }
  return out;
}

function usage() {
  console.log(`
MyGrowth Diet App — Main Admin bootstrap
=========================================

Creates the single MAIN_ADMIN account. Run once.

  npm run bootstrap:admin -- --email <email> [--password <password>]
      [--first-name <name>] [--last-name <name>]

Environment fallbacks: ADMIN_EMAIL, ADMIN_PASSWORD, ADMIN_FIRST_NAME,
ADMIN_LAST_NAME.

If --password is omitted, a strong password is generated and printed once.
Only one Main Admin may ever exist; re-running this script after the Main
Admin exists is a no-op.
`);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    usage();
    return;
  }

  const email = String(args.email || process.env.ADMIN_EMAIL || '')
    .trim()
    .toLowerCase();
  if (!email || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    usage();
    throw new Error('A valid --email (or ADMIN_EMAIL) is required.');
  }

  const firstName = String(args['first-name'] || process.env.ADMIN_FIRST_NAME || 'Main').trim();
  const lastName = String(args['last-name'] || process.env.ADMIN_LAST_NAME || 'Administrator').trim();

  let password = args.password || process.env.ADMIN_PASSWORD;
  let generated = false;
  if (!password) {
    password = randomBytes(18).toString('base64url');
    generated = true;
  }
  password = String(password);
  const minLength = config.isProd ? 12 : 8;
  if (password.length < minLength) {
    throw new Error(`Password must be at least ${minLength} characters.`);
  }

  const passwordHash = await hashPassword(password);

  const result = await prisma.$transaction(
    async (tx) => {
      // Serialize concurrent bootstrap attempts.
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(918273645)`;
      const existingMainAdmin = await tx.user.findFirst({ where: { role: 'MAIN_ADMIN' } });
      if (existingMainAdmin) {
        return { created: false, existing: existingMainAdmin };
      }
      const user = await tx.user.create({
        data: {
          email,
          firstName,
          lastName,
          passwordHash,
          role: 'MAIN_ADMIN',
          status: 'ACTIVE',
          adminAccess: 'ACTIVE',
          emailVerifiedAt: new Date(),
          timezone: 'Africa/Lagos',
        },
      });
      return { created: true, user };
    },
    { isolationLevel: 'Serializable' }
  );

  if (!result.created) {
    console.log(
      `A Main Admin already exists (${result.existing.email}). No second Main Admin can be created — bootstrap is complete.`
    );
    return;
  }

  await audit({
    actorId: result.user.id,
    actorRole: 'MAIN_ADMIN',
    actorEmail: result.user.email,
    action: 'main_admin_bootstrapped',
    targetType: 'user',
    targetId: result.user.id,
    details: { email: result.user.email },
  });

  console.log('\nMain Admin created successfully.');
  console.log('---------------------------------------------');
  console.log(`Email:    ${result.user.email}`);
  if (generated) {
    console.log(`Password: ${password}`);
    console.log('\nStore this password securely and change it after first login.');
  } else {
    console.log('Password: (the value you supplied)');
  }
  console.log('---------------------------------------------\n');
}

main()
  .catch((err) => {
    console.error(`[bootstrap:admin] ${err.message}`);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
