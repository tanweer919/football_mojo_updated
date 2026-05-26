import { CanActivate, ExecutionContext, ForbiddenException, Injectable, SetMetadata } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Request } from 'express';
import { PrismaService } from '../../common/prisma.service';

/**
 * Two-tier privilege gate for admin endpoints.
 *
 * Use after `FirebaseAuthGuard` — that guard verifies the bearer token and
 * populates `req.user.uid`. This guard then maps the uid to a User row and
 * compares `role` against the route's declared minimum.
 *
 * Default minimum (when no `@RequireRole(...)` decorator is present) is
 * `ADMIN`. Apply `@RequireRole('SUPERADMIN')` on individual handlers that
 * mint admins or rotate other admins' roles.
 */

export const ADMIN_ROLE_KEY = 'admin_role';
export const RequireRole = (role: 'ADMIN' | 'SUPERADMIN') => SetMetadata(ADMIN_ROLE_KEY, role);

@Injectable()
export class AdminRoleGuard implements CanActivate {
  constructor(
    private readonly prisma: PrismaService,
    private readonly reflector: Reflector,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest<Request>();
    const uid = req.user?.uid;
    if (!uid) throw new ForbiddenException('not_authenticated');

    const user = await this.prisma.user.findUnique({
      where: { id: uid },
      select: { role: true },
    });
    if (!user) throw new ForbiddenException('user_not_found');

    // The decorator overrides the default minimum; without it any admin row
    // (ADMIN or SUPERADMIN) is accepted.
    const required = this.reflector.getAllAndOverride<'ADMIN' | 'SUPERADMIN' | undefined>(
      ADMIN_ROLE_KEY,
      [ctx.getHandler(), ctx.getClass()],
    );
    if (required === 'SUPERADMIN') {
      if (user.role !== 'SUPERADMIN') throw new ForbiddenException('superadmin_required');
    } else {
      if (user.role !== 'ADMIN' && user.role !== 'SUPERADMIN') {
        throw new ForbiddenException('admin_required');
      }
    }
    return true;
  }
}
