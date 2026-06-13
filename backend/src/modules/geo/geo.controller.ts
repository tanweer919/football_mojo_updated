import { Controller, Get, Req } from '@nestjs/common';
import type { Request } from 'express';
import { GeoService } from './geo.service';

/**
 * Public `GET /v1/geo/country` → `{ country: "IN" | null }`, resolved from the
 * caller's IP. NOT HTTP-cached (the CacheInterceptor keys by URL, which would
 * leak one user's country to everyone) — per-IP caching lives in Redis.
 */
@Controller({ path: 'geo', version: '1' })
export class GeoController {
  constructor(private readonly geo: GeoService) {}

  @Get('country')
  async country(@Req() req: Request) {
    // A CDN/edge-provided country header (Cloudflare) is authoritative + free.
    const header = (req.headers['cf-ipcountry'] as string | undefined)?.toUpperCase();
    if (header && header.length === 2 && header !== 'XX') return { country: header };
    return { country: await this.geo.countryForIp(this.clientIp(req)) };
  }

  /** Real client IP behind Dokploy/Traefik (no `trust proxy` set), via XFF. */
  private clientIp(req: Request): string | null {
    const xff = req.headers['x-forwarded-for'];
    if (typeof xff === 'string' && xff.length) return xff.split(',')[0].trim();
    if (Array.isArray(xff) && xff.length) return xff[0].split(',')[0].trim();
    const xr = req.headers['x-real-ip'];
    if (typeof xr === 'string' && xr.length) return xr.trim();
    return req.ip ?? req.socket?.remoteAddress ?? null;
  }
}
