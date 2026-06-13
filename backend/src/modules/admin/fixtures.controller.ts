import { Body, Controller, Delete, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { IsInt, IsOptional, IsString, MaxLength, Min } from 'class-validator';
import { BroadcastsService } from '../broadcasts/broadcasts.service';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { AdminRoleGuard } from './admin-role.guard';

class WatchLinkBody {
  @IsString() @MaxLength(120) name!: string;
  @IsOptional() @IsString() @MaxLength(2000) url?: string | null;
  @IsOptional() @IsString() @MaxLength(2) countryCode?: string | null;
  @IsOptional() @IsString() @MaxLength(80) countryName?: string | null;
  @IsOptional() @IsString() @MaxLength(2000) logoUrl?: string | null;
  @IsOptional() @IsInt() @Min(0) position?: number;
}

/**
 * Admin: browse fixtures and curate per-fixture watch links (name + link,
 * optionally per country). Double-guarded like the rest of the admin API.
 * Mounted at /v1/admin/fixtures/*.
 */
@Controller({ path: 'admin/fixtures', version: '1' })
@UseGuards(FirebaseAuthGuard, AdminRoleGuard)
export class AdminFixturesController {
  constructor(private readonly broadcasts: BroadcastsService) {}

  @Get()
  list(@Query('q') q?: string, @Query('page') page?: string, @Query('pageSize') pageSize?: string) {
    return this.broadcasts.listFixtures({
      q: q?.trim() || undefined,
      page: Math.max(1, Number.parseInt(page ?? '1', 10) || 1),
      pageSize: Math.min(100, Math.max(1, Number.parseInt(pageSize ?? '40', 10) || 40)),
    });
  }

  @Get(':id')
  getOne(@Param('id') id: string) {
    return this.broadcasts.getFixture(id);
  }

  @Post(':id/watch-links')
  create(@Param('id') id: string, @Body() body: WatchLinkBody) {
    return this.broadcasts.createLink(id, body);
  }

  @Patch('watch-links/:linkId')
  update(@Param('linkId') linkId: string, @Body() body: WatchLinkBody) {
    return this.broadcasts.updateLink(linkId, body);
  }

  @Delete('watch-links/:linkId')
  remove(@Param('linkId') linkId: string) {
    return this.broadcasts.deleteLink(linkId);
  }
}
