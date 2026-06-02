import {
  CanActivate,
  ExecutionContext,
  Injectable,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import { Request } from 'express';
import { PrismaService } from '../../common/prisma.service';
import { FirebaseAdminService } from './firebase-admin.service';
import { createUserWithUniqueTag } from './user-tag';

declare module 'express' {
  interface Request {
    user?: { uid: string; email?: string };
  }
}

@Injectable()
export class FirebaseAuthGuard implements CanActivate {
  private readonly log = new Logger(FirebaseAuthGuard.name);

  constructor(
    private readonly firebase: FirebaseAdminService,
    private readonly prisma: PrismaService,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest<Request>();
    const header = req.headers.authorization;
    if (!header?.startsWith('Bearer ')) throw new UnauthorizedException('missing_token');
    const token = header.slice(7);

    let decoded;
    try {
      decoded = await this.firebase.verifyIdToken(token);
    } catch {
      throw new UnauthorizedException('invalid_token');
    }

    // Firebase token claim names for the photo URL — covers both
    // `picture` (standard OIDC claim, set by Google) and `photoURL`
    // (older Firebase shape). Strip the size suffix (`=s96-c`) so we
    // store the original-sized image — clients can resize as needed.
    const rawPhoto =
      (decoded as Record<string, unknown>).picture as string | undefined ??
      (decoded as Record<string, unknown>).photoURL as string | undefined;
    const photoUrl = rawPhoto ? rawPhoto.replace(/=s\d+(-c)?$/, '') : null;

    // Lazy-create the user row on first authenticated request. Split into
    // find-then-create so the tag generator only runs on genuine first
    // sign-up — repeat requests skip straight through. On the read-path
    // we also opportunistically backfill photoUrl when the token has one
    // and our row doesn't.
    const existing = await this.prisma.user.findUnique({
      where: { id: decoded.uid },
      select: { id: true, photoUrl: true, displayName: true },
    });
    if (!existing) {
      try {
        const tag = await createUserWithUniqueTag(this.prisma, decoded.uid, {
          email: decoded.email ?? null,
          displayName: decoded.name ?? null,
          photoUrl,
        });
        this.log.log(`new user provisioned: uid=${decoded.uid} tag=@${tag}`);
      } catch (e) {
        // Hard failure (DB down, exhausted retries) — fail closed so the
        // caller doesn't continue with no row in DB.
        this.log.error(`user provisioning failed: ${(e as Error).message}`);
        throw new UnauthorizedException('user_provisioning_failed');
      }
    } else if (photoUrl && !existing.photoUrl) {
      // Backfill for users created before this column was populated, OR
      // newly-linked Google accounts. Do NOT overwrite an existing photo
      // since the user may have set their own.
      await this.prisma.user
        .update({
          where: { id: decoded.uid },
          data: { photoUrl },
        })
        .catch((e) => this.log.warn(`photoUrl backfill failed for ${decoded.uid}: ${(e as Error).message}`));
    }

    req.user = { uid: decoded.uid, email: decoded.email };
    return true;
  }
}
