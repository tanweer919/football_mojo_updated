import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Request } from 'express';
import { PrismaService } from '../../common/prisma.service';
import { FirebaseAdminService } from './firebase-admin.service';

declare module 'express' {
  interface Request {
    user?: { uid: string; email?: string };
  }
}

@Injectable()
export class FirebaseAuthGuard implements CanActivate {
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

    // Lazy-create the user row on first authenticated request.
    await this.prisma.user.upsert({
      where: { id: decoded.uid },
      create: { id: decoded.uid, email: decoded.email ?? null, displayName: decoded.name ?? null },
      update: {},
    });

    req.user = { uid: decoded.uid, email: decoded.email };
    return true;
  }
}
