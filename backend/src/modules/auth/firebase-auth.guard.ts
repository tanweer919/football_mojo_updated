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

    // Lazy-create the user row on first authenticated request. Split into
    // find-then-create so the tag generator only runs on genuine first
    // sign-up — repeat requests skip straight through.
    const existing = await this.prisma.user.findUnique({
      where: { id: decoded.uid },
      select: { id: true },
    });
    if (!existing) {
      try {
        const tag = await createUserWithUniqueTag(this.prisma, decoded.uid, {
          email: decoded.email ?? null,
          displayName: decoded.name ?? null,
        });
        this.log.log(`new user provisioned: uid=${decoded.uid} tag=@${tag}`);
      } catch (e) {
        // Hard failure (DB down, exhausted retries) — fail closed so the
        // caller doesn't continue with no row in DB.
        this.log.error(`user provisioning failed: ${(e as Error).message}`);
        throw new UnauthorizedException('user_provisioning_failed');
      }
    }

    req.user = { uid: decoded.uid, email: decoded.email };
    return true;
  }
}
