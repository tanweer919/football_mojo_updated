import { Controller, Get } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/**
 * Public (no auth) endpoint returning client-side feature flags.
 *
 * Thin on purpose — flags are env-driven so a deploy toggles them
 * instantly across every client without a DB migration.
 *
 * GET /v1/app-config
 */
@Controller({ path: 'app-config', version: '1' })
export class AppConfigController {
  constructor(private readonly cfg: ConfigService) {}

  @Get()
  getConfig() {
    return {
      // When true the Flutter home screen hides dormant European-league
      // sections and promotes World Cup content. Toggle off via env
      // WC_MODE=false after the tournament ends.
      wcMode: this.cfg.get<string>('WC_MODE', 'true') === 'true',
    };
  }
}
