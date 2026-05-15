import { Controller, Get, UseGuards } from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { UsersService } from './users.service';

@Controller({ path: 'users', version: '1' })
@UseGuards(FirebaseAuthGuard)
export class UsersController {
  constructor(private readonly users: UsersService) {}

  /**
   * Profile screen aggregate. One request → user, stats, achievements,
   * followed-team summary.
   */
  @Get('me')
  me(@CurrentUser('uid') uid: string) {
    return this.users.me(uid);
  }
}
