import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { PlayerPosition } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsEnum,
  IsOptional,
  IsString,
  ValidateNested,
} from 'class-validator';
import { CurrentUser } from '../auth/current-user.decorator';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { SQUAD } from './fantasy.constants';
import { FantasyService, LineupPick } from './fantasy.service';

// Decorated so the global ValidationPipe (whitelist + forbidNonWhitelisted)
// recognises these fields. Without decorators every property gets stripped
// and the request is rejected with "property X should not exist".
class LineupPickBody {
  @IsString()
  playerId!: string;

  @IsEnum(PlayerPosition)
  position!: PlayerPosition;

  @IsOptional()
  @IsBoolean()
  isCaptain?: boolean;
}

class SubmitLineupBody {
  @IsArray()
  @ArrayMinSize(1)
  @ValidateNested({ each: true })
  @Type(() => LineupPickBody)
  picks!: LineupPickBody[];

  @IsString()
  captainId!: string;
}

@Controller({ path: 'fantasy', version: '1' })
export class FantasyController {
  constructor(private readonly fantasy: FantasyService) {}

  // Public — anyone can browse tournaments.
  @Get('tournaments')
  list() { return this.fantasy.listTournaments(); }

  @Get('tournaments/:slug')
  get(@Param('slug') slug: string) { return this.fantasy.getTournament(slug); }

  @Get('tournaments/:slug/current-gameweek')
  async current(@Param('slug') slug: string) {
    const t = await this.fantasy.getTournament(slug);
    return this.fantasy.currentGameweek(t.id);
  }

  @Get('tournaments/:slug/players')
  players(@Param('slug') slug: string) {
    return this.fantasy.getTournament(slug).then((t) => this.fantasy.listSelectablePlayers(t.id));
  }

  @Get('tournaments/:slug/gameweeks/:gwId/leaderboard')
  leaderboard(
    @Param('gwId') gwId: string,
    @Query('limit') limit?: string,
  ) {
    return this.fantasy.leaderboard(gwId, limit ? +limit : 100);
  }

  // Authenticated routes
  @UseGuards(FirebaseAuthGuard)
  @Post('tournaments/:slug/gameweeks/:gwId/lineup')
  submit(
    @CurrentUser('uid') uid: string,
    @Param('gwId') gwId: string,
    @Body() body: SubmitLineupBody,
  ) {
    return this.fantasy.submitLineup(uid, gwId, body.picks as LineupPick[], body.captainId);
  }

  @UseGuards(FirebaseAuthGuard)
  @Get('tournaments/:slug/gameweeks/:gwId/lineup/mine')
  mine(@CurrentUser('uid') uid: string, @Param('gwId') gwId: string) {
    return this.fantasy.getMyLineup(uid, gwId);
  }

  @Get('rules')
  rules() {
    return { squad: SQUAD };
  }
}
