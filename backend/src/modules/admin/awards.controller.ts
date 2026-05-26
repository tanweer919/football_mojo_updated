import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { AwardType } from '@prisma/client';
import { IsIn, IsObject, IsString } from 'class-validator';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { AwardsService } from '../awards/awards.service';
import { AdminRoleGuard } from './admin-role.guard';

class ResolveAwardsBody {
  @IsString()
  competitionId!: string;

  /// `winners` is a sparse map — the caller only fills in the awards that
  /// have been decided. Partial submissions are allowed (golden boot
  /// usually settles before the others) so resolution is incremental.
  @IsObject()
  winners!: Partial<Record<AwardType, string>>;
}

@Controller({ path: 'admin/awards', version: '1' })
@UseGuards(FirebaseAuthGuard, AdminRoleGuard)
export class AdminAwardsController {
  constructor(private readonly awards: AwardsService) {}

  /// Resolve award picks for a tournament. Idempotent — the underlying
  /// gem credit dedupes on (user, source, award:<comp>:<type>) so re-runs
  /// don't double-pay correct picks. Bad winnerId is rejected at the FK
  /// level since `playerId` is a known-existing player.
  @Post('resolve')
  resolve(@Body() body: ResolveAwardsBody) {
    const cleaned: Partial<Record<AwardType, string>> = {};
    for (const [key, value] of Object.entries(body.winners ?? {})) {
      // Whitelist the enum so callers can't write arbitrary garbage into
      // the resolve loop.
      if (
        (key === 'GOLDEN_BOOT' || key === 'GOLDEN_BALL' || key === 'BEST_YOUNG_PLAYER') &&
        typeof value === 'string' && value.length > 0
      ) {
        cleaned[key as AwardType] = value;
      }
    }
    return this.awards.resolve(body.competitionId, cleaned);
  }
}
