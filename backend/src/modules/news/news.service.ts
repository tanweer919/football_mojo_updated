import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/prisma.service';

@Injectable()
export class NewsService {
  constructor(private readonly prisma: PrismaService) {}

  /// List articles. Filtering rules:
  ///   - teamId (single)  → articles where teamIds[] contains that id
  ///   - teamIds (multi)  → articles where teamIds[] contains ANY of them
  ///                         (used by the home "Following" tab — OR-joined)
  ///   - source           → exact source name match
  /// Both teamId and teamIds can be passed; they're combined as a single
  /// hasSome set so callers don't have to pick one shape.
  async list(params: {
    limit?: number;
    cursor?: string;
    teamId?: string;
    teamIds?: string[];
    source?: string;
  }) {
    const limit = Math.min(params.limit ?? 20, 50);
    const where: Record<string, unknown> = {};

    // Merge single + multi into one set, dedupe, drop empties.
    const idSet = new Set<string>();
    if (params.teamId) idSet.add(params.teamId);
    for (const id of params.teamIds ?? []) {
      if (id && id.trim()) idSet.add(id.trim());
    }
    if (idSet.size > 0) {
      where.teamIds = { hasSome: [...idSet] };
    }
    if (params.source) where.source = params.source;

    const items = await this.prisma.newsArticle.findMany({
      where,
      orderBy: { publishedAt: 'desc' },
      take: limit + 1,
      ...(params.cursor ? { cursor: { id: params.cursor }, skip: 1 } : {}),
    });
    const nextCursor = items.length > limit ? items.pop()?.id : null;
    return { items, nextCursor };
  }

  async getById(id: string) {
    return this.prisma.newsArticle.findUnique({ where: { id } });
  }
}
