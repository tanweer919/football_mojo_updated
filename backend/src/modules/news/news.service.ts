import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../common/prisma.service';

@Injectable()
export class NewsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(params: { limit?: number; cursor?: string; teamId?: string; source?: string }) {
    const limit = Math.min(params.limit ?? 20, 50);
    const where: Record<string, unknown> = {};
    if (params.teamId) where.teamIds = { has: params.teamId };
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
