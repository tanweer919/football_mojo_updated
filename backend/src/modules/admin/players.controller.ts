import { Body, Controller, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { IsInt, IsOptional, IsString } from 'class-validator';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { AdminRoleGuard } from './admin-role.guard';
import { AdminPlayersService } from './players.service';

class UpdatePlayerBody {
  @IsString() name!: string;
  @IsOptional() @IsString() photoUrl?: string | null;
  @IsOptional() @IsString() position?: string | null;
  @IsOptional() @IsString() nationality?: string | null;
  @IsOptional() @IsInt() shirtNumber?: number | null;
  @IsString() teamId!: string;
}

@Controller({ path: 'admin/players', version: '1' })
@UseGuards(FirebaseAuthGuard, AdminRoleGuard)
export class AdminPlayersController {
  constructor(private readonly players: AdminPlayersService) {}

  @Get()
  list(
    @Query('q') q?: string,
    @Query('photo') photo?: 'cutout' | 'any' | 'none',
    @Query('page') page?: string,
    @Query('pageSize') pageSize?: string,
  ) {
    return this.players.list({
      q: q?.trim() || undefined,
      photo,
      page: Math.max(1, Number.parseInt(page ?? '1', 10) || 1),
      // Clamp page size so a malicious caller can't request the whole table.
      pageSize: Math.min(100, Math.max(1, Number.parseInt(pageSize ?? '30', 10) || 30)),
    });
  }

  @Get(':id')
  getOne(@Param('id') id: string) {
    return this.players.getById(id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() body: UpdatePlayerBody) {
    return this.players.update(id, {
      name: body.name,
      photoUrl: body.photoUrl?.trim() || null,
      position: body.position?.trim() || null,
      nationality: body.nationality?.trim() || null,
      shirtNumber: body.shirtNumber ?? null,
      teamId: body.teamId,
    });
  }

  @Post(':id/refresh-photo')
  refreshPhoto(@Param('id') id: string) {
    return this.players.refreshPhotoFromSportsDb(id);
  }
}
