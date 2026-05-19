import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma.service';

interface ListInput {
  q?: string;
  photo?: 'cutout' | 'any' | 'none';
  page: number;
  pageSize: number;
}

interface UpdateInput {
  name: string;
  photoUrl: string | null;
  position: string | null;
  nationality: string | null;
  shirtNumber: number | null;
  teamId: string;
}

interface SportsDbHit {
  strPlayer: string;
  strTeam: string | null;
  strSport: string | null;
  strNationality: string | null;
  strThumb: string | null;
  strCutout: string | null;
}

@Injectable()
export class AdminPlayersService {
  constructor(private readonly prisma: PrismaService) {}

  async list(input: ListInput) {
    const where = {
      AND: [
        input.q ? { name: { contains: input.q, mode: 'insensitive' as const } } : {},
        input.photo === 'cutout' ? { photoUrl: { contains: 'thesportsdb.com' } } : {},
        input.photo === 'any'    ? { photoUrl: { not: null } } : {},
        input.photo === 'none'   ? { photoUrl: null } : {},
      ],
    };
    const [rows, total] = await Promise.all([
      this.prisma.player.findMany({
        where,
        include: { team: { select: { id: true, name: true, shortName: true, crestUrl: true } } },
        orderBy: { name: 'asc' },
        take: input.pageSize,
        skip: (input.page - 1) * input.pageSize,
      }),
      this.prisma.player.count({ where }),
    ]);
    return { rows, total };
  }

  async getById(id: string) {
    const p = await this.prisma.player.findUnique({
      where: { id },
      include: {
        team: { select: { id: true, name: true, shortName: true, crestUrl: true } },
        cardTemplates: {
          select: { id: true, edition: true, rarity: true, totalSupply: true, mintedCount: true, artUrl: true },
        },
      },
    });
    if (!p) throw new NotFoundException('player_not_found');
    return p;
  }

  /// Update a player + cascade `photoUrl` to every CardTemplate that
  /// snapshots it. The cascade is the whole reason this is a transaction.
  ///
  /// `CardTemplate.artUrl` is non-nullable in the schema, so if the admin
  /// clears the player photo we leave each template's existing art alone
  /// (the card still renders) — the admin can edit individual templates'
  /// art directly if they really want it gone.
  async update(id: string, input: UpdateInput) {
    const writes = [
      this.prisma.player.update({
        where: { id },
        data: {
          name: input.name.trim(),
          photoUrl: input.photoUrl,
          position: input.position,
          nationality: input.nationality,
          shirtNumber: input.shirtNumber,
          teamId: input.teamId,
        },
      }),
    ];
    if (input.photoUrl) {
      writes.push(
        this.prisma.cardTemplate.updateMany({
          where: { playerId: id },
          data: { artUrl: input.photoUrl },
        }) as unknown as (typeof writes)[number],
      );
    }
    await this.prisma.$transaction(writes);
  }

  /// Single-row photo refresh via TheSportsDB — same heuristics as the
  /// bulk script, condensed. Throws BadRequest when no candidate passes
  /// the surname + initial filter.
  async refreshPhotoFromSportsDb(id: string) {
    const p = await this.prisma.player.findUnique({
      where: { id },
      select: { name: true, nationality: true, team: { select: { name: true } } },
    });
    if (!p) throw new NotFoundException('player_not_found');

    const tokens = p.name.trim().split(/\s+/);
    const surname = tokens[tokens.length - 1];
    const firstInitial = tokens.length > 1 && tokens[0].length <= 2
      ? tokens[0].replace(/[^A-Za-zÀ-ÿ]/g, '')[0]?.toUpperCase() ?? null
      : tokens[0][0]?.toUpperCase() ?? null;

    const apiKey = process.env.THESPORTSDB_KEY ?? '123';
    const url = `https://www.thesportsdb.com/api/v1/json/${apiKey}/searchplayers.php?p=${encodeURIComponent(surname)}`;
    const res = await fetch(url);
    if (!res.ok) throw new BadRequestException(`upstream_${res.status}`);
    const body = (await res.json()) as { player: SportsDbHit[] | null };
    const hits = (body.player ?? []).filter((h) => (h.strSport ?? '').toLowerCase() === 'soccer');

    const scored = hits
      .map((h) => {
        const initialOk = !firstInitial || h.strPlayer.trim()[0]?.toUpperCase() === firstInitial;
        if (!initialOk) return null;
        let score = 0;
        if (this._norm(h.strTeam) === this._norm(p.team?.name ?? null)) score += 8;
        if (this._norm(h.strNationality) === this._norm(p.nationality)) score += 4;
        if (h.strCutout) score += 2;
        return { h, score };
      })
      .filter((x): x is { h: SportsDbHit; score: number } => x !== null)
      .sort((a, b) => b.score - a.score);

    const pick = scored[0]?.h;
    if (!pick) throw new BadRequestException('no_match_on_sportsdb');
    const newUrl = pick.strCutout || pick.strThumb;
    if (!newUrl) throw new BadRequestException('match_has_no_image');

    await this.prisma.$transaction([
      this.prisma.player.update({ where: { id }, data: { photoUrl: newUrl } }),
      this.prisma.cardTemplate.updateMany({ where: { playerId: id }, data: { artUrl: newUrl } }),
    ]);
    return { url: newUrl, matched: pick.strPlayer };
  }

  private _norm(s: string | null | undefined): string {
    if (!s) return '';
    return s.normalize('NFD').replace(/\p{Diacritic}/gu, '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
  }
}
