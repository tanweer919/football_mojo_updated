import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { IsString, MaxLength, MinLength } from 'class-validator';
import { BroadcastsService } from '../broadcasts/broadcasts.service';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { AdminRoleGuard } from './admin-role.guard';

class ChannelOverrideBody {
  @IsString() @MinLength(1) @MaxLength(120) name!: string;
  @IsString() @MinLength(1) @MaxLength(2000) url!: string;
}

/**
 * Admin: global per-channel watch-link overrides (name → url), applied to every
 * matching broadcast at serve time. `GET` returns existing overrides plus the
 * channels that still have no link (so the admin knows what to add).
 * Mounted at /v1/admin/channels/*.
 */
@Controller({ path: 'admin/channels', version: '1' })
@UseGuards(FirebaseAuthGuard, AdminRoleGuard)
export class AdminChannelsController {
  constructor(private readonly broadcasts: BroadcastsService) {}

  @Get()
  async list() {
    const [overrides, missing] = await Promise.all([
      this.broadcasts.listChannelOverrides(),
      this.broadcasts.missingChannels(),
    ]);
    return { overrides, missing };
  }

  @Post()
  create(@Body() body: ChannelOverrideBody) {
    return this.broadcasts.createChannelOverride(body);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() body: ChannelOverrideBody) {
    return this.broadcasts.updateChannelOverride(id, body);
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.broadcasts.deleteChannelOverride(id);
  }
}
