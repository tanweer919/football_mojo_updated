import { Injectable, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as admin from 'firebase-admin';

@Injectable()
export class FirebaseAdminService implements OnModuleInit {
  private app!: admin.app.App;

  constructor(private readonly cfg: ConfigService) {}

  onModuleInit() {
    if (admin.apps.length) {
      this.app = admin.app();
      return;
    }
    const b64 = this.cfg.get<string>('FIREBASE_SERVICE_ACCOUNT_B64');
    if (!b64) {
      // Allow local dev without firebase by exposing a no-op shim.
      // Production deploys MUST provide the env var.
      return;
    }
    const json = JSON.parse(Buffer.from(b64, 'base64').toString('utf8'));
    this.app = admin.initializeApp({ credential: admin.credential.cert(json) });
  }

  async verifyIdToken(token: string) {
    return admin.auth().verifyIdToken(token);
  }

  async sendToTokens(tokens: string[], notification: { title: string; body: string }, data?: Record<string, string>) {
    if (!tokens.length) return { successCount: 0, failureCount: 0 };
    return admin.messaging().sendEachForMulticast({ tokens, notification, data });
  }

  async sendToTopic(topic: string, notification: { title: string; body: string }, data?: Record<string, string>) {
    return admin.messaging().send({ topic, notification, data });
  }
}
