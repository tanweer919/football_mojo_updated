import { Body, Controller, Get, Param, Patch, Post, Query, Req, UseGuards } from '@nestjs/common';
import { IsBoolean, IsEmail, IsIn, IsString } from 'class-validator';
import { Request } from 'express';
import { UserRole } from '@prisma/client';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { AdminRoleGuard, RequireRole } from './admin-role.guard';
import { AdminUsersService } from './users.service';

const ROLES: UserRole[] = ['USER', 'ADMIN', 'SUPERADMIN'];

class SetRoleBody {
  @IsIn(ROLES) role!: UserRole;
}
class InviteBody {
  @IsEmail() email!: string;
  @IsBoolean() asSuper!: boolean;
}
class SetTagBody {
  @IsString() tag!: string;
}

@Controller({ path: 'admin/users', version: '1' })
@UseGuards(FirebaseAuthGuard, AdminRoleGuard)
export class AdminUsersController {
  constructor(private readonly users: AdminUsersService) {}

  @Get()
  list(
    @Query('q') q?: string,
    @Query('role') role?: string,
    @Query('page') page?: string,
    @Query('pageSize') pageSize?: string,
  ) {
    return this.users.list({
      q: q?.trim() || undefined,
      role: ROLES.includes(role as UserRole) ? (role as UserRole) : undefined,
      page: Math.max(1, Number.parseInt(page ?? '1', 10) || 1),
      pageSize: Math.min(100, Math.max(1, Number.parseInt(pageSize ?? '30', 10) || 30)),
    });
  }

  // Role mutations require SUPERADMIN — the decorator overrides the
  // controller-level ADMIN default.
  @Patch(':id/role')
  @RequireRole('SUPERADMIN')
  setRole(@Req() req: Request, @Param('id') targetId: string, @Body() body: SetRoleBody) {
    return this.users.setRole(req.user!.uid, targetId, body.role);
  }

  @Post('invite')
  @RequireRole('SUPERADMIN')
  invite(@Body() body: InviteBody) {
    return this.users.invite(body.email, body.asSuper ? 'SUPERADMIN' : 'ADMIN');
  }

  @Patch(':id/tag')
  setTag(@Param('id') id: string, @Body() body: SetTagBody) {
    return this.users.setUserTag(id, body.tag);
  }
}
