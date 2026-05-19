import { CacheInterceptor, CacheTTL } from '@nestjs/cache-manager';
import { Controller, Get, Param, Query, UseInterceptors } from '@nestjs/common';
import { UsersService } from '../users/users.service';
import { CompetitionsService } from './competitions.service';

@Controller({ path: 'competitions', version: '1' })
@UseInterceptors(CacheInterceptor)
export class CompetitionsController {
  constructor(
    private readonly competitions: CompetitionsService,
    // Public team search lives on this controller because team belongs to
    // competition. Reuses UsersService where the implementation already
    // exists — no point duplicating the Prisma query.
    private readonly users: UsersService,
  ) {}

  /**
   * App startup call. Cached for 5 min on the server so a million clients
   * fetching at once == a few hundred DB queries per minute.
   */
  @Get()
  @CacheTTL(300_000)
  list(@Query('active') active?: string) {
    return this.competitions.list({ onlyActive: active === 'true' });
  }

  @Get('primary')
  @CacheTTL(300_000)
  primary() {
    return this.competitions.primary();
  }

  @Get(':id')
  @CacheTTL(300_000)
  get(@Param('id') id: string) {
    return this.competitions.get(id);
  }

  @Get(':id/overview')
  @CacheTTL(300_000)
  overview(@Param('id') id: string) {
    return this.competitions.overview(id);
  }

  @Get(':id/groups')
  @CacheTTL(300_000)
  groups(@Param('id') id: string) {
    return this.competitions.groups(id);
  }

  /// `GET /v1/competitions/teams/search?q=arsenal&competitionId=PL_2025`
  /// Public — drives the favourites picker. Both params optional; capped
  /// at 50 hits by the service.
  @Get('teams/search')
  @CacheTTL(60_000)
  searchTeams(
    @Query('q') q?: string,
    @Query('competitionId') competitionId?: string,
  ) {
    return this.users.searchTeams({ q, competitionId });
  }
}
