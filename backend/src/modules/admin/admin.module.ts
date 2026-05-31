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
import { AdminUsersController } from './users.controller';
import { AdminUsersService } from './users.service';
import { AdminTeamsController } from './teams.controller';
import { AdminTeamsService } from './teams.service';

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
    AdminUsersService,
    AdminTeamsService,
  ],
  controllers: [
    AdminDashboardController,
    AdminPlayersController,
    AdminCardsController,
    AdminUsersController,
    AdminTeamsController,
    AdminAwardsController,
  ],
})
export class AdminModule {}
