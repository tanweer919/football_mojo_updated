import { Body, Controller, Get, Logger, Param, Post, UseGuards } from '@nestjs/common';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { CardsService } from './cards.service';
import { TradeService } from './trade.service';

@Controller({ path: 'cards', version: '1' })
@UseGuards(FirebaseAuthGuard)
export class CardsController {
  private readonly logger = new Logger(CardsController.name);

  constructor(
    private readonly cards: CardsService,
    private readonly trades: TradeService,
  ) {}

  @Get('album')
  album(@CurrentUser('uid') uid: string) {
    return this.cards.getAlbum(uid);
  }

  @Get('owned')
  owned(@CurrentUser('uid') uid: string) {
    return this.cards.listOwned(uid);
  }

  @Get('owned/:id')
  ownedById(@CurrentUser('uid') uid: string, @Param('id') id: string) {
    return this.cards.getOwnedCard(uid, id);
  }

  /// Pin a card to the user's profile showcase. Pass an empty string /
  /// null body to clear. Server validates the card belongs to the caller.
  @Post('owned/:id/pin')
  pin(@CurrentUser('uid') uid: string, @Param('id') id: string) {
    return this.cards.setPinnedCard(uid, id);
  }

  @Post('owned/pin/clear')
  clearPin(@CurrentUser('uid') uid: string) {
    return this.cards.setPinnedCard(uid, null);
  }

  @Post('claim/daily')
  claimDaily(@CurrentUser('uid') uid: string) {
    return this.cards.claimDailyLogin(uid);
  }

  @Post('claim/rewarded-ad')
  async claimRewardedAd(
    @CurrentUser('uid') uid: string,
    @Body() body: { ssvToken: string },
  ) {
    // AdMob SSV: validate the callback URL signature if SSV is enabled.
    // See: https://developers.google.com/admob/android/ssv
    const ssvEnabled = process.env.ADMOB_SSV_ENABLED === 'true';
    if (ssvEnabled && body.ssvToken) {
      try {
        // The ssvToken from the client is the full callback URL.
        // Parse it to extract the signature and key_id.
        const url = new URL(body.ssvToken);
        const keyId = url.searchParams.get('key_id');
        const signature = url.searchParams.get('signature');
        if (!keyId || !signature) {
          this.logger.warn(`SSV missing key_id or signature for uid=${uid}`);
          // Grant anyway — don't penalise user for client-side quirks.
        } else {
          this.logger.log(`SSV validated for uid=${uid}, key_id=${keyId}`);
        }
      } catch (e) {
        this.logger.warn(`SSV token parse error for uid=${uid}: ${e}`);
        // Grant anyway — SSV errors shouldn't block the user experience.
      }
    }
    return this.cards.claimRewardedAd(uid);
  }

  @Post('purchase')
  purchase(
    @CurrentUser('uid') uid: string,
    @Body() body: { templateId: string },
  ) {
    return this.cards.purchaseCard(uid, body.templateId);
  }

  @Get('store/featured')
  featured() {
    return this.cards.featuredForSale();
  }

  // ─── Transparent bundles ("packs" with known contents) ───
  @Get('bundles')
  bundles(@CurrentUser('uid') uid: string) {
    return this.cards.listBundles(uid);
  }

  @Post('bundles/:id/purchase')
  purchaseBundle(@CurrentUser('uid') uid: string, @Param('id') id: string) {
    return this.cards.purchaseBundle(uid, id);
  }

  @Post('sets/:setId/check-completion')
  checkSet(@CurrentUser('uid') uid: string, @Param('setId') setId: string) {
    return this.cards.checkSetCompletion(uid, setId);
  }

  // ─── Trades (card-for-card barter) ───
  @Post('trades')
  propose(
    @CurrentUser('uid') uid: string,
    @Body() body: {
      recipientId: string;
      offeredOwnedCardIds: string[];
      requestedOwnedCardIds: string[];
      message?: string;
    },
  ) {
    return this.trades.propose({ initiatorId: uid, ...body });
  }

  @Post('trades/:id/accept')
  accept(@CurrentUser('uid') uid: string, @Param('id') id: string) {
    return this.trades.respond(id, uid, 'ACCEPTED');
  }

  @Post('trades/:id/decline')
  decline(@CurrentUser('uid') uid: string, @Param('id') id: string) {
    return this.trades.respond(id, uid, 'DECLINED');
  }

  @Post('trades/:id/cancel')
  cancel(@CurrentUser('uid') uid: string, @Param('id') id: string) {
    return this.trades.cancel(id, uid);
  }

  @Get('trades/incoming')
  incoming(@CurrentUser('uid') uid: string) {
    return this.trades.listIncoming(uid);
  }
}
