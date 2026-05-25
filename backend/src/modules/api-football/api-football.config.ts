/**
 * api-football auth + base URL. Supports both access paths:
 *
 *   1) Direct via api-sports.io
 *      API_FOOTBALL_PROVIDER=direct  (default)
 *      base:    https://v3.football.api-sports.io
 *      header:  x-apisports-key: <key>
 *
 *   2) RapidAPI marketplace
 *      API_FOOTBALL_PROVIDER=rapidapi
 *      base:    https://api-football-v1.p.rapidapi.com/v3
 *      headers: x-rapidapi-key:  <key>
 *               x-rapidapi-host: api-football-v1.p.rapidapi.com
 *
 * The JSON envelope is byte-identical between the two — only auth + host change.
 * Same shared module is used by the Nest client AND the prisma seed.
 */
export interface ApiFootballAxiosConfig {
  baseURL: string;
  headers: Record<string, string>;
}

const RAPIDAPI_HOST = 'api-football-v1.p.rapidapi.com';

export function resolveApiFootballConfig(env: NodeJS.ProcessEnv = process.env): ApiFootballAxiosConfig {
  const key = env.API_FOOTBALL_KEY;
  if (!key) throw new Error('API_FOOTBALL_KEY is required');

  const provider = (env.API_FOOTBALL_PROVIDER ?? 'direct').toLowerCase();
  if (provider === 'rapidapi') {
    return {
      baseURL: env.API_FOOTBALL_BASE ?? `https://${RAPIDAPI_HOST}/v3`,
      headers: {
        'x-rapidapi-host': RAPIDAPI_HOST,
        'x-rapidapi-key':  key,
      },
    };
  }
  return {
    baseURL: env.API_FOOTBALL_BASE ?? 'https://v3.football.api-sports.io',
    headers: { 'x-apisports-key': key },
  };
}
