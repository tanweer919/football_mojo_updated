import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma.service';

@Injectable()
export class AdminTeamsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(input: { q?: string; competitionId?: string; page: number; pageSize: number }) {
    const where = {
      AND: [
        input.competitionId ? { competitionId: input.competitionId } : {},
        input.q ? { name: { contains: input.q, mode: 'insensitive' as const } } : {},
      ],
    };
    const [rows, total, competitions] = await Promise.all([
      this.prisma.team.findMany({
        where,
        include: {
          competition: { select: { id: true, name: true } },
          _count: { select: { players: true } },
        },
        orderBy: { name: 'asc' },
        take: input.pageSize,
        skip: (input.page - 1) * input.pageSize,
      }),
      this.prisma.team.count({ where }),
      this.prisma.competition.findMany({ select: { id: true, name: true }, orderBy: { name: 'asc' } }),
    ]);
    return { rows, total, competitions };
  }

  async getById(id: string) {
    const t = await this.prisma.team.findUnique({
      where: { id },
      include: {
        competition: { select: { id: true, name: true } },
        _count: { select: { players: true, homeMatches: true, awayMatches: true } },
      },
    });
    if (!t) throw new NotFoundException('team_not_found');
    return t;
  }

  async update(id: string, input: {
    name: string;
    shortName: string;
    countryCode: string | null;
    crestUrl: string | null;
    primaryColor: string | null;
  }) {
    await this.prisma.team.update({
      where: { id },
      data: input,
    });
  }
}
