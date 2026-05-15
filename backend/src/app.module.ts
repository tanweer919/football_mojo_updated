import { CacheModule } from '@nestjs/cache-manager';
import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { ScheduleModule } from '@nestjs/schedule';
import { ThrottlerModule } from '@nestjs/throttler';
import { redisStore } from 'cache-manager-ioredis-yet';
import { LoggerModule } from 'nestjs-pino';

import { HealthController } from './common/health.controller';
import { PrismaModule } from './common/prisma.module';
import { RedisModule } from './common/redis.module';
import { ApiFootballModule } from './modules/api-football/api-football.module';
import { AuthModule } from './modules/auth/auth.module';
import { CardsModule } from './modules/cards/cards.module';
import { CompetitionsModule } from './modules/competitions/competitions.module';
import { FantasyModule } from './modules/fantasy/fantasy.module';
import { GlobalCupModule } from './modules/global-cup/global-cup.module';
import { H2HModule } from './modules/h2h/h2h.module';
import { InsightsModule } from './modules/insights/insights.module';
import { NewsModule } from './modules/news/news.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { PredictionsModule } from './modules/predictions/predictions.module';
import { ScoresModule } from './modules/scores/scores.module';
import { UsersModule } from './modules/users/users.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, cache: true }),
    LoggerModule.forRoot({
      pinoHttp: {
        transport: process.env.NODE_ENV === 'production' ? undefined : { target: 'pino-pretty' },
        redact: ['req.headers.authorization', 'req.headers.cookie'],
      },
    }),
    ScheduleModule.forRoot(),
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 120 }]),
    CacheModule.registerAsync({
      isGlobal: true,
      inject: [ConfigService],
      useFactory: async (cfg: ConfigService) => {
        // cache-manager-ioredis-yet >= 2.x takes ioredis options, not a url field.
        const url = new URL(cfg.getOrThrow<string>('REDIS_URL'));
        return {
          store: await redisStore({
            host: url.hostname,
            port: Number(url.port || 6379),
            password: url.password || undefined,
            ttl: 30_000,
          }),
        };
      },
    }),
    PrismaModule,
    RedisModule,
    ApiFootballModule,
    AuthModule,
    ScoresModule,
    NewsModule,
    PredictionsModule,
    CardsModule,
    CompetitionsModule,
    FantasyModule,
    H2HModule,
    GlobalCupModule,
    InsightsModule,
    NotificationsModule,
    UsersModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}
