import { CanActivate, ExecutionContext, Injectable, Logger } from '@nestjs/common';
import { Request } from 'express';
import { FirebaseAdminService } from './firebase-admin.service';

/**
 * Best-effort auth: if a valid Bearer token is present, populate `req.user`.
 * Anonymous requests (no token / bad token) pass through unblocked with
 * `req.user` left undefined.
 *
 * Use on public endpoints that *enhance* their response when the caller is
 * signed in — e.g. the cards marketplace, which adds an "owned by me" tag.
 */
@Injectable()
export class OptionalFirebaseAuthGuard implements CanActivate {
  private readonly log = new Logger(OptionalFirebaseAuthGuard.name);

  constructor(private readonly firebase: FirebaseAdminService) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest<Request>();
    const header = req.headers.authorization;
    if (!header?.startsWith('Bearer ')) return true; // anonymous: allowed.

    try {
      const decoded = await this.firebase.verifyIdToken(header.slice(7));
      req.user = { uid: decoded.uid, email: decoded.email };
    } catch {
      // Swallow — treat malformed/expired tokens as anonymous so the screen
      // still renders. Endpoints that strictly need auth should use the
      // regular FirebaseAuthGuard instead.
    }
    return true;
  }
}
