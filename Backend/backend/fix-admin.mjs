import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  const oldEmail = (process.env.OLD_ADMIN_EMAIL || 'admin@gmail.com').trim().toLowerCase();
  const newEmail = process.env.ADMIN_EMAIL?.trim().toLowerCase();
  const password = process.env.ADMIN_PASSWORD;

  if (process.env.CONFIRM_ADMIN_RESET !== 'YES') {
    throw new Error('Set CONFIRM_ADMIN_RESET=YES to confirm this admin account change.');
  }
  if (!newEmail || !password) {
    throw new Error('Set ADMIN_EMAIL and ADMIN_PASSWORD in the environment before running this script.');
  }
  if (password.length < 12) {
    throw new Error('ADMIN_PASSWORD must be at least 12 characters.');
  }

  const hash = await bcrypt.hash(password, 10);
  const existing = await prisma.user.findUnique({ where: { email: newEmail } });

  if (existing) {
    await prisma.user.update({
      where: { id: existing.id },
      data: {
        passwordHash: hash,
        role: 'MAIN_ADMIN',
        adminAccess: 'ACTIVE',
        status: 'ACTIVE',
      },
    });
    console.log(`Updated main admin account: ${newEmail}`);
    return;
  }

  const old = await prisma.user.findUnique({ where: { email: oldEmail } });
  if (old) {
    await prisma.user.update({
      where: { id: old.id },
      data: {
        email: newEmail,
        passwordHash: hash,
        role: 'MAIN_ADMIN',
        adminAccess: 'ACTIVE',
        status: 'ACTIVE',
      },
    });
    console.log(`Renamed main admin account ${oldEmail} to ${newEmail}`);
    return;
  }

  await prisma.user.create({
    data: {
      email: newEmail,
      passwordHash: hash,
      firstName: 'Main',
      lastName: 'Admin',
      role: 'MAIN_ADMIN',
      adminAccess: 'ACTIVE',
      status: 'ACTIVE',
      emailVerifiedAt: new Date(),
    },
  });
  console.log(`Created main admin account: ${newEmail}`);
}

main()
  .catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
