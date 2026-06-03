import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { AwardsModule } from '../awards/awards.module';
import { AdminAwardsController } from './awards.controller';
import { AdminRoleGuard } from './admin-role.guard';
import { AdminDashboardController } from './dashboard.controller';
import { AdminPlayersController } from './players.controller';
import { AdminPlayersService } from './players.service';
import { AdminCardsController } from './cards.controller';
import { AdminCardsService } from './cards.service';
import { AdminBundlesController } from './bundles.controller';
import { AdminBundlesService } from './bundles.service';
import { AdminUsersController } from './users.controller';
import { AdminUsersService } from './users.service';
import { AdminTeamsController } from './teams.controller';
import { AdminTeamsService } from './teams.service';
import { PhotoBatchController } from './photo-batch.controller';

/**
 * Admin API. Every controller in here is double-guarded:
 *   1. FirebaseAuthGuard — verifies the bearer ID token, populates req.user.
 *   2. AdminRoleGuard    — maps uid → User.role and rejects USER.
 *
 * Mounted at `/v1/admin/*`. Consumed by the Next.js admin panel.
 */
@Module({
  imports: [AuthModule, AwardsModule],
  providers: [
    AdminRoleGuard,
    AdminPlayersService,
    AdminCardsService,
    AdminBundlesService,
    AdminUsersService,
    AdminTeamsService,
  ],
  controllers: [
    AdminDashboardController,
    AdminPlayersController,
    AdminCardsController,
    AdminBundlesController,
    AdminUsersController,
    AdminTeamsController,
    AdminAwardsController,
    PhotoBatchController,
  ],
})
export class AdminModule {}
