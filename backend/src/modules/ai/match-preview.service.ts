import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';
import { AiService } from './ai.service';

const TYPE = 'match_preview';
// Re-generate an upcoming match's preview if the cached one is older than
// this (injuries/lineups move). Finished matches are cached permanently.
const FRESH_MS = 6 * 60 * 60 * 1000;

@Injectable()
export class MatchPreviewService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ai: AiService,
  ) {}

  /// On-demand AI match preview, cached per match. First caller generates it;
  /// everyone else (until it's stale) is served the cached copy.
  async getPreview(matchId: string) {
    const match = await this.prisma.match.findUnique({
      where: { id: matchId },
      include: { homeTeam: true, awayTeam: true, competition: true },
    });
    if (!match) throw new NotFoundException('match_not_found');

    const cached = await this.prisma.aiContent.findUnique({
      where: { type_refId: { type: TYPE, refId: matchId } },
    });
    const finished = match.status === 'FINISHED' || match.status === 'CANCELLED';
    if (cached && (finished || Date.now() - cached.updatedAt.getTime() < FRESH_MS)) {
      return this.shape(cached);
    }

    const { text, sources, model } = await this.ai.generateGrounded(this.buildPrompt(match));
    const sourcesJson = sources as unknown as Prisma.InputJsonValue;
    const saved = await this.prisma.aiContent.upsert({
      where: { type_refId: { type: TYPE, refId: matchId } },
      create: { type: TYPE, refId: matchId, content: text, sources: sourcesJson, model },
      update: { content: text, sources: sourcesJson, model },
    });
    return this.shape(saved);
  }

  private shape(c: { content: string; sources: unknown; model: string; updatedAt: Date }) {
    return {
      content: c.content,
      sources: c.sources ?? [],
      model: c.model,
      generatedAt: c.updatedAt,
    };
  }

  private buildPrompt(m: {
    homeTeam: { name: string };
    awayTeam: { name: string };
    competition: { name: string } | null;
    competitionId: string;
    kickoffAt: Date;
    venue: string | null;
    status: string;
    homeScore: number;
    awayScore: number;
  }): string {
    const comp = m.competition?.name ?? m.competitionId;
    const venue = m.venue ? ` at ${m.venue}` : '';
    if (m.status === 'FINISHED') {
      return (
        `You are a concise football analyst. Write a short, factual recap of the finished match ` +
        `${m.homeTeam.name} ${m.homeScore}-${m.awayScore} ${m.awayTeam.name} (${comp})${venue}. ` +
        `Cover how it unfolded, the key moments and standout players, using current information. ` +
        `110-150 words, plain text, neutral tone. No betting tips or odds.`
      );
    }
    const ko = m.kickoffAt.toISOString().slice(0, 16).replace('T', ' ') + ' UTC';
    return (
      `You are a concise football analyst. Write a short, factual preview of the upcoming match ` +
      `${m.homeTeam.name} vs ${m.awayTeam.name} (${comp})${venue}, kicking off ${ko}. ` +
      `Use current information: recent form, key injuries or suspensions, head-to-head, and what is at stake. ` +
      `120-160 words, plain text, neutral tone. End with one line starting "Key battle:". ` +
      `Do not include betting tips or odds.`
    );
  }
}
