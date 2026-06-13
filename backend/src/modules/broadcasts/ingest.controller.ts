import {
  Body,
  CanActivate,
  Controller,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { IsObject } from 'class-validator';
import { BroadcastsService } from './broadcasts.service';

/**
 * Server-to-server guard for the scraper cron — a static shared secret in the
 * `x-ingest-key` header (env SCRAPER_INGEST_KEY), not Firebase, since there's
 * no human / ID token in a cron. Refuses if the env key is unset.
 */
@Injectable()
export class IngestKeyGuard implements CanActivate {
  constructor(private readonly cfg: ConfigService) {}
  canActivate(ctx: ExecutionContext): boolean {
    const expected = this.cfg.get<string>('SCRAPER_INGEST_KEY');
    const got = ctx.switchToHttp().getRequest().headers['x-ingest-key'];
    if (!expected || got !== expected) throw new ForbiddenException('bad_ingest_key');
    return true;
  }
}

class IngestBody {
  @IsObject() fixtures!: Record<string, any>;
}

@Controller({ path: 'admin/broadcasts', version: '1' })
export class IngestController {
  constructor(private readonly broadcasts: BroadcastsService) {}

  /** Bulk upsert SCRAPER links: POST /v1/admin/broadcasts/ingest */
  @Post('ingest')
  @UseGuards(IngestKeyGuard)
  ingest(@Body() body: IngestBody) {
    return this.broadcasts.ingest(body.fixtures ?? {});
  }
}
