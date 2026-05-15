import { Inject, Logger, OnModuleInit } from '@nestjs/common';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import Redis from 'ioredis';
import { Server, Socket } from 'socket.io';
import { REDIS_SUB } from '../../common/redis.module';
import { CHANNELS } from './scores.events';

@WebSocketGateway({
  cors: { origin: '*' },          // tighten in production via CORS_ORIGINS
  transports: ['websocket'],
  path: '/realtime',
})
export class ScoresGateway implements OnModuleInit, OnGatewayConnection, OnGatewayDisconnect {
  private readonly log = new Logger(ScoresGateway.name);
  @WebSocketServer() io!: Server;

  constructor(@Inject(REDIS_SUB) private readonly sub: Redis) {}

  async onModuleInit() {
    // Pattern subscribe to every per-match channel + the global fixtures channel.
    await this.sub.psubscribe('match:*:update', 'match:*:event');
    await this.sub.subscribe(CHANNELS.fixturesUpdate);

    this.sub.on('pmessage', (_pattern, channel, message) => {
      // channel: match:{id}:update | match:{id}:event
      const [, id, kind] = channel.split(':');
      const room = `match_${id}`;
      this.io.to(room).emit(kind === 'update' ? 'match.update' : 'match.event', JSON.parse(message));
    });

    this.sub.on('message', (channel, message) => {
      if (channel === CHANNELS.fixturesUpdate) {
        this.io.to('fixtures').emit('fixtures.update', JSON.parse(message));
      }
    });
  }

  handleConnection(client: Socket) {
    this.log.debug(`ws connect ${client.id}`);
  }

  handleDisconnect(client: Socket) {
    this.log.debug(`ws disconnect ${client.id}`);
  }

  @SubscribeMessage('subscribe.match')
  onSubscribeMatch(@ConnectedSocket() c: Socket, @MessageBody() data: { id: string }) {
    if (!data?.id) return { ok: false };
    c.join(`match_${data.id}`);
    return { ok: true, room: `match_${data.id}` };
  }

  @SubscribeMessage('unsubscribe.match')
  onUnsubscribeMatch(@ConnectedSocket() c: Socket, @MessageBody() data: { id: string }) {
    c.leave(`match_${data.id}`);
    return { ok: true };
  }

  @SubscribeMessage('subscribe.fixtures')
  onSubscribeFixtures(@ConnectedSocket() c: Socket) {
    c.join('fixtures');
    return { ok: true };
  }
}
