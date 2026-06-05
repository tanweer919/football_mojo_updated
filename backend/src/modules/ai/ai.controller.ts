import { Controller, Param, Post, UseGuards } from '@nestjs/common';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { MatchPreviewService } from './match-preview.service';

/// AI features. Auth-guarded (anonymous Firebase users included) so we can
/// attribute/limit usage; the heavy lifting is cached, so repeat taps and
/// other users for the same match are free.
@Controller({ path: 'ai', version: '1' })
@UseGuards(FirebaseAuthGuard)
export class AiController {
  constructor(private readonly preview: MatchPreviewService) {}

  @Post('matches/:id/preview')
  matchPreview(@Param('id') id: string) {
    return this.preview.getPreview(id);
  }
}
