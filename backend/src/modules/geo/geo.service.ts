import { Inject, Injectable, Logger } from '@nestjs/common';
import axios from 'axios';
import Redis from 'ioredis';
import { REDIS_PUB } from '../../common/redis.module';

/**
 * Resolve an ISO-3166 alpha-2 country from a client IP. Uses ip-api.com — which
 * is fine to call HTTP server-side (no mobile cleartext/ATS restriction) — and
 * caches per-IP in Redis so repeat callers are free and we stay well under
 * ip-api's 45 req/min/source limit. Returns null for private/local IPs.
 */
@Injectable()
export class GeoService {
  private readonly log = new Logger(GeoService.name);
  constructor(@Inject(REDIS_PUB) private readonly redis: Redis) {}

  async countryForIp(ip: string | null): Promise<string | null> {
    if (!ip || this.isPrivate(ip)) return null;

    const key = `geo:country:${ip}`;
    const cached = await this.redis.get(key);
    if (cached) return cached === '-' ? null : cached;

    let code: string | null = null;
    try {
      const res = await axios.get(`http://ip-api.com/json/${encodeURIComponent(ip)}`, {
        params: { fields: 'status,countryCode' },
        timeout: 4000,
      });
      if (res.data?.status === 'success' && typeof res.data.countryCode === 'string') {
        code = res.data.countryCode.toUpperCase();
      }
    } catch (e) {
      this.log.warn(`geo lookup failed for ${ip}: ${(e as Error).message}`);
    }

    // Cache positives for a day; negatives briefly so transient failures retry.
    await this.redis.set(key, code ?? '-', 'EX', code ? 86_400 : 3_600);
    return code;
  }

  private isPrivate(ip: string): boolean {
    const v = ip.replace('::ffff:', '');
    return (
      v === '127.0.0.1' ||
      v === '::1' ||
      v === 'localhost' ||
      v.startsWith('10.') ||
      v.startsWith('192.168.') ||
      /^172\.(1[6-9]|2\d|3[01])\./.test(v)
    );
  }
}
