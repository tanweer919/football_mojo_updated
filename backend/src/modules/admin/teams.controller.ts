import { Body, Controller, Get, Param, Patch, Query, UseGuards } from '@nestjs/common';
import { IsOptional, IsString } from 'class-validator';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { AdminRoleGuard } from './admin-role.guard';
import { AdminTeamsService } from './teams.service';

class UpdateTeamBody {
  @IsString() name!: string;
  @IsString() shortName!: string;
  @IsOptional() @IsString() countryCode?: string | null;
  @IsOptional() @IsString() crestUrl?: string | null;
  @IsOptional() @IsString() primaryColor?: string | null;
}

@Controller({ path: 'admin/teams', version: '1' })
@UseGuards(FirebaseAuthGuard, AdminRoleGuard)
export class AdminTeamsController {
  constructor(private readonly teams: AdminTeamsService) {}

  @Get()
  list(
    @Query('q') q?: string,
    @Query('competitionId') competitionId?: string,
    @Query('page') page?: string,
    @Query('pageSize') pageSize?: string,
  ) {
    return this.teams.list({
      q: q?.trim() || undefined,
      competitionId: competitionId?.trim() || undefined,
      page: Math.max(1, Number.parseInt(page ?? '1', 10) || 1),
      pageSize: Math.min(100, Math.max(1, Number.parseInt(pageSize ?? '40', 10) || 40)),
    });
  }

  @Get(':id')
  getOne(@Param('id') id: string) {
    return this.teams.getById(id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() body: UpdateTeamBody) {
    return this.teams.update(id, {
      name: body.name.trim(),
      shortName: body.shortName.trim() || body.name.trim().slice(0, 3).toUpperCase(),
      countryCode: body.countryCode?.trim().toUpperCase() || null,
      crestUrl: body.crestUrl?.trim() || null,
      primaryColor: body.primaryColor?.trim() || null,
    });
  }
}
