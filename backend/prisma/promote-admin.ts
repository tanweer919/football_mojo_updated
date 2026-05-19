/**
 * Promote a user to ADMIN (or SUPERADMIN) — out-of-band privilege grant.
 *
 * Two paths:
 *   1. The email already maps to a User row (the typical case — the admin
 *      has installed the mobile app and signed in once). We just update
 *      `role`.
 *   2. The email has never seen the mobile app. We create a new User with
 *      a cuid id (no Firebase UID) and the requested role. The Next.js
 *      admin panel logs in by Google email, so a Firebase UID is not
 *      required for admin access.
 *
 * Usage:
 *   npm run admin:promote -- alice@example.com
 *   npm run admin:promote -- alice@example.com --super
 *   npm run admin:promote -- alice@example.com --demote   # → USER
 *
 * Idempotent — re-running with the same role is a no-op.
 */

import { PrismaClient, UserRole } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import 'dotenv/config';

const prisma = new PrismaClient();

function parseArgs() {
  const args = process.argv.slice(2);
  const email = args.find((a) => !a.startsWith('--'));
  const wantSuper = args.includes('--super');
  const wantDemote = args.includes('--demote');
  if (!email) {
    console.error('Usage: npm run admin:promote -- <email> [--super | --demote]');
    process.exit(1);
  }
  if (wantSuper && wantDemote) {
    console.error('Pick one: --super or --demote, not both.');
    process.exit(1);
  }
  const targetRole: UserRole = wantDemote ? 'USER' : wantSuper ? 'SUPERADMIN' : 'ADMIN';
  return { email: email.trim().toLowerCase(), targetRole };
}

async function main() {
  const { email, targetRole } = parseArgs();

  const existing = await prisma.user.findUnique({
    where: { email },
    select: { id: true, role: true, displayName: true, userTag: true },
  });

  if (existing) {
    if (existing.role === targetRole) {
      console.log(`✓ ${email} is already ${targetRole} — no change.`);
      return;
    }
    await prisma.user.update({
      where: { email },
      data: { role: targetRole },
    });
    console.log(`✓ ${email} (${existing.displayName ?? existing.id}): ${existing.role} → ${targetRole}`);
    return;
  }

  // Email isn't tied to any account yet — create one. The id slot is filled
  // with a randomUUID (not a Firebase UID) so the admin can sign in by email
  // via the Next.js admin panel without ever having installed the mobile app.
  const id = `admin_${randomUUID()}`;
  const created = await prisma.user.create({
    data: { id, email, role: targetRole },
    select: { id: true, email: true, role: true },
  });
  console.log(`✓ created admin shell: ${created.email} (${created.id}) — role ${created.role}`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
