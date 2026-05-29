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

    // Decode + validate explicitly so a bad env var produces an actionable
    // error instead of a cryptic `SyntaxError: Unexpected token`. Two common
    // foot-guns we explicitly catch:
    //   1. Raw JSON pasted instead of base64-encoded text.
    //   2. base64 with embedded whitespace / quotes from a paste mishap.
    const cleaned = b64.trim().replace(/\s+/g, '');
    if (cleaned.startsWith('{')) {
      throw new Error(
        'FIREBASE_SERVICE_ACCOUNT_B64 looks like raw JSON — base64-encode it first: ' +
        '`base64 -i service-account.json | tr -d "\\n"`',
      );
    }

    let decoded: string;
    try {
      decoded = Buffer.from(cleaned, 'base64').toString('utf8');
    } catch (e) {
      throw new Error(
        `FIREBASE_SERVICE_ACCOUNT_B64 is not valid base64: ${(e as Error).message}`,
      );
    }

    let json: Record<string, unknown>;
    try {
      json = JSON.parse(decoded) as Record<string, unknown>;
    } catch (e) {
      throw new Error(
        'FIREBASE_SERVICE_ACCOUNT_B64 decoded to non-JSON. The value is likely ' +
        'corrupted (line breaks during paste, wrong file, or double-encoded). ' +
        `First 60 decoded chars: ${decoded.slice(0, 60).replace(/[\x00-\x1f]/g, '?')}`,
      );
    }
    if (!json.project_id || !json.client_email || !json.private_key) {
      throw new Error(
        'FIREBASE_SERVICE_ACCOUNT_B64 decoded JSON is missing project_id / client_email / private_key. ' +
        'Verify it\'s a Firebase Admin SDK service account (Console → Project Settings → ' +
        'Service accounts → Generate new private key), not an OAuth client secret.',
      );
    }

    this.app = admin.initializeApp({
      // `cert()` expects ServiceAccount shape; cast is safe after we've
      // validated the three required fields above.
      credential: admin.credential.cert(json as admin.ServiceAccount),
    });
  }

  async verifyIdToken(token: string) {
    return admin.auth().verifyIdToken(token);
  }

  async sendToTokens(tokens: string[], notification: { title: string; body: string }, data?: Record<string, string>) {
    if (!tokens.length) return { successCount: 0, failureCount: 0, invalidTokens: [] as string[] };
    const res = await admin.messaging().sendEachForMulticast({ tokens, notification, data });
    // Collect tokens FCM tells us are dead so callers can scrub them.
    // The two codes that mean "permanently invalid" are:
    //   - messaging/invalid-registration-token  (malformed or wrong app)
    //   - messaging/registration-token-not-registered  (user uninstalled / re-installed)
    // Transient errors (rate limit, unavailable) stay in the array.
    const invalidTokens: string[] = [];
    res.responses.forEach((r, i) => {
      if (r.success || !r.error) return;
      const code = r.error.code;
      if (
        code === 'messaging/invalid-registration-token' ||
        code === 'messaging/registration-token-not-registered'
      ) {
        invalidTokens.push(tokens[i]!);
      }
    });
    return {
      successCount: res.successCount,
      failureCount: res.failureCount,
      invalidTokens,
    };
  }

  async sendToTopic(topic: string, notification: { title: string; body: string }, data?: Record<string, string>) {
    return admin.messaging().send({ topic, notification, data });
  }
}
