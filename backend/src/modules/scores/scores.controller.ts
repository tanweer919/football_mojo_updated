import { CacheInterceptor, CacheTTL } from '@nestjs/cache-manager';
import { Controller, Get, NotFoundException, Param, Query, UseInterceptors } from '@nestjs/common';
import { ScoresService } from './scores.service';

@Controller({ path: 'scores', version: '1' })
@UseInterceptors(CacheInterceptor)
export class ScoresController {
  constructor(private readonly scores: ScoresService) {}

  @Get('live')
  @CacheTTL(5_000)
  live() {
    return this.scores.getLive();
  }

  @Get('fixtures')
  @CacheTTL(60_000)
  fixtures(@Query('day') day?: string) {
    return this.scores.getFixturesForDay(day ?? new Date().toISOString().slice(0, 10));
  }

  /// Multi-day window in one request (home / My Team / matches screens).
  @Get('fixtures/range')
  @CacheTTL(60_000)
  fixturesRange(@Query('from') from: string, @Query('to') to: string) {
    return this.scores.getFixturesRange(from, to);
  }

  @Get('matches/:id')
  @CacheTTL(10_000)
  async match(@Param('id') id: string) {
    const m = await this.scores.getMatchDetail(id);
    if (!m) throw new NotFoundException('match_not_found');
    return m;
  }

  @Get('competitions/:competitionId/standings')
  @CacheTTL(60_000)
  standings(@Param('competitionId') id: string) {
    return this.scores.getStandings(id);
  }
}
