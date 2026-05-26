import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/rarity_theme.dart';
import '../../features/album/data/models/card_models.dart';

/// PITCH player card — Sorare-style layout with a luxe per-rarity gradient
/// background.
///
/// Visual layers (back → front):
///   1. base linear gradient (per-rarity, multi-stop)
///   2. soft radial highlight at the top (faux light source)
///   3. diagonal specular sweep ("card laminate" effect)
///   4. holographic sheen — stronger on the high tiers
///   5. inner hairline frame + rarity-tinted outer outline
///   6. hexagon rating (top-left) + club crest (top-right)
///   7. player photo — tinted + edge-faded so the white headshot bg
///      blends into the card instead of punching as a bright rectangle
///   8. bottom dark block — compact meta strip + name + edition footer
///
/// Defaults are forgiving: the only required field is `rarity`. Pass as
/// much rich data as you have (`firstName`, `lastName`, `age`, `clubCrestUrl`,
/// `leagueLabel`, `editionLabel`) and the card lights up; pass nothing and it
/// falls back to a clean tile.
class PCard extends StatelessWidget {
  const PCard({
    super.key,
    required this.rarity,
    // Rating > 0 surfaces the hexagon score badge top-left. Set to 0 to hide.
    this.rating = 0,
    this.name,
    this.firstName,
    this.lastName,
    this.position,
    this.country,
    this.age,
    this.photoUrl,
    this.clubCrestUrl,
    this.leagueLabel,
    this.editionLabel,
    // Owned-card identity. When both `serialNumber` and `totalSupply` are
    // set, a `#42 / 250` chip renders on the bottom-right of the card —
    // the most-loved Sorare touch, makes every owned copy feel unique.
    this.serialNumber,
    this.totalSupply,
    // Card level (0..5 stars). Earned from XP — see OwnedCard.xp. Zero
    // hides the row entirely so unowned templates don't show fake stars.
    this.level = 0,
    // Trophy count badge — rendered top-left when > 0.
    this.trophies = 0,
    this.width,
    this.onTap,
    this.heroTag,
  });

  final CardRarity rarity;
  final int rating;

  /// Full name. Split on whitespace for the two-line block when
  /// `firstName` / `lastName` aren't provided.
  final String? name;
  final String? firstName;
  final String? lastName;
  final String? position;
  final String? country;
  final int? age;
  final String? photoUrl;
  final String? clubCrestUrl;
  final String? leagueLabel;
  final String? editionLabel;
  /// Owned-card identity — surfaces `#42 / 250` when both are non-null.
  final int? serialNumber;
  final int? totalSupply;
  /// 0..5 — 5 stars next to the name once enough XP is accumulated.
  final int level;
  /// Trophy count — rendered as a small medal badge top-left.
  final int trophies;
  final double? width;
  final VoidCallback? onTap;
  final Object? heroTag;

  static const _aspect = 0.66;

  /// We treat any photo served from TheSportsDB as a transparent PNG cutout
  /// — those are the high-quality, alpha-clean images we deliberately
  /// switched to via `refresh:photos`. Anything else (api-football,
  /// uploads, etc.) is still assumed to be a hard-rectangle photo that
  /// needs the blend/mask treatment to stop reading as a bright tile.
  static bool _isCutout(String? url) =>
      url != null && url.contains('thesportsdb.com');

  @override
  Widget build(BuildContext context) {
    final theme = RarityTheme.of(rarity);
    final (first, last) = _splitName();
    final cc = _iso3(country);
    final isCutout = _isCutout(photoUrl);

    Widget core = AspectRatio(
      aspectRatio: _aspect,
      // Outer container picks up the rarity-tinted glow + a deep drop
      // shadow so adjacent cards in a dense grid never visually touch.
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: theme.accentTint.withValues(alpha: 0.12),
              blurRadius: 14,
              spreadRadius: -2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. base gradient
              DecoratedBox(decoration: BoxDecoration(gradient: theme.cardGradient)),
              // 2. radial light source at top
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.85),
                    radius: 1.1,
                    colors: [
                      theme.accentTint.withValues(alpha: 0.32),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.7],
                  ),
                ),
              ),
              // 3. diagonal specular sweep — gives the "card laminate" feel.
              const _Specular(),
              // 4. holographic sheen — only visible on Rare and above.
              if (theme.foilOpacity > 0.3) _HolographicSheen(theme: theme),
              // 5a. floor glow — soft rarity-tinted ellipse painted at the
              //     bottom-centre of the photo area, behind the player. Only
              //     visible for cutout PNGs because legacy white-bg photos
              //     fully occlude this area. Adds a "spotlight" sense of
              //     depth so the player reads as standing on something.
              if (isCutout) _FloorGlow(tint: theme.accentTint),
              // 5b. player photo (sits behind chrome, in front of bg).
              //     Cutouts get a much taller frame and bottom-anchor so the
              //     player reaches almost edge-to-edge and "stands on" the
              //     name band. White-bg fallbacks keep the cautious centred
              //     layout the radial mask was designed for.
              Positioned.fill(
                child: Padding(
                  padding: isCutout
                      ? const EdgeInsets.fromLTRB(2, 12, 2, 78)
                      : const EdgeInsets.fromLTRB(8, 50, 8, 96),
                  child: _PlayerPhoto(
                    url: photoUrl,
                    lastName: last,
                    tint: theme.accentTint,
                    isCutout: isCutout,
                  ),
                ),
              ),
              // 6. inner hairline frame + rarity-tinted outer outline
              _Frames(rarity: rarity, tint: theme.accentTint),
              // 7. top chrome — big hex rating left, club crest right
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (rating > 0)
                      _HexRating(rating: rating, color: theme.ratingColor, glow: theme.accentTint)
                    else
                      const SizedBox.shrink(),
                    const Spacer(),
                    if (clubCrestUrl != null) _Crest(url: clubCrestUrl!),
                  ],
                ),
              ),
              // Small league tag under the hex (subtle, doesn't fight for
              // attention with the prominent rating).
              if (leagueLabel != null)
                Positioned(
                  left: 8,
                  top: rating > 0 ? 50 : 12,
                  child: _LeagueTag(label: leagueLabel!),
                ),
              // Trophy badge under the league tag, when this card has
              // been used in a winning XI / completed a set / etc.
              if (trophies > 0)
                Positioned(
                  left: 8,
                  top: rating > 0 ? 76 : 38,
                  child: _TrophyBadge(count: trophies),
                ),
              // Serial-of-N chip, bottom-right of the card. The most-
              // loved Sorare touch — makes #5 of 100 different from #94
              // even though they share the same template art.
              if (serialNumber != null && totalSupply != null)
                Positioned(
                  right: 8, bottom: 90,
                  child: _SerialChip(serial: serialNumber!, total: totalSupply!, theme: theme),
                ),
              // 8. bottom dark block — meta strip + name + edition footer
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: _BottomBlock(
                  country: cc,
                  position: position,
                  age: age,
                  firstName: first,
                  lastName: last,
                  editionLabel: editionLabel,
                  level: level,
                  accent: theme.ratingColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (heroTag != null) {
      core = Hero(tag: heroTag!, child: Material(color: Colors.transparent, child: core));
    }
    if (width != null) {
      core = SizedBox(width: width, child: core);
    }
    if (onTap == null) return core;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: core);
  }

  (String, String) _splitName() {
    if (firstName != null || lastName != null) {
      return (firstName ?? '', lastName ?? '');
    }
    final raw = (name ?? '').trim();
    if (raw.isEmpty) return ('', '');
    final parts = raw.split(RegExp(r'\s+'));
    if (parts.length == 1) return ('', parts.first);
    // Treat the last whitespace-delimited token as the surname; everything
    // before it is the given-name block (handles middle names and initials).
    final ln = parts.last;
    final fn = parts.sublist(0, parts.length - 1).join(' ');
    return (fn, ln);
  }
}

// ─── Country normalization ───────────────────────────────────────────────

/// api-football's `nationality` field returns full country names (e.g.
/// "England", "New-Zealand"). Sorare-style cards want a 3-letter ISO code
/// instead. We keep a small lookup for the common WC + Big-Five nations and
/// fall back to "first 3 letters" for anything unmapped — better than the
/// status quo of letting "NEW-ZEALAND" overflow the meta strip.
String _iso3(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final s = raw.trim();
  if (s.length <= 3) return s.toUpperCase();
  final k = s.toLowerCase().replaceAll('-', ' ').trim();
  const m = {
    'england': 'ENG', 'scotland': 'SCO', 'wales': 'WAL', 'northern ireland': 'NIR',
    'republic of ireland': 'IRL', 'ireland': 'IRL',
    'france': 'FRA', 'spain': 'ESP', 'germany': 'GER', 'italy': 'ITA',
    'portugal': 'POR', 'netherlands': 'NED', 'holland': 'NED', 'belgium': 'BEL',
    'switzerland': 'SUI', 'austria': 'AUT', 'denmark': 'DEN', 'sweden': 'SWE',
    'norway': 'NOR', 'finland': 'FIN', 'iceland': 'ISL', 'poland': 'POL',
    'czech republic': 'CZE', 'czechia': 'CZE', 'slovakia': 'SVK', 'hungary': 'HUN',
    'romania': 'ROU', 'bulgaria': 'BUL', 'serbia': 'SRB', 'croatia': 'CRO',
    'slovenia': 'SVN', 'bosnia': 'BIH', 'albania': 'ALB', 'greece': 'GRE',
    'turkey': 'TUR', 'ukraine': 'UKR', 'russia': 'RUS', 'belarus': 'BLR',
    'argentina': 'ARG', 'brazil': 'BRA', 'uruguay': 'URU', 'chile': 'CHI',
    'colombia': 'COL', 'peru': 'PER', 'ecuador': 'ECU', 'paraguay': 'PAR',
    'bolivia': 'BOL', 'venezuela': 'VEN', 'mexico': 'MEX', 'canada': 'CAN',
    'united states': 'USA', 'usa': 'USA', 'costa rica': 'CRC', 'panama': 'PAN',
    'jamaica': 'JAM', 'honduras': 'HON',
    'japan': 'JPN', 'south korea': 'KOR', 'korea republic': 'KOR', 'iran': 'IRN',
    'saudi arabia': 'KSA', 'qatar': 'QAT', 'australia': 'AUS', 'new zealand': 'NZL',
    'china': 'CHN', 'india': 'IND', 'iraq': 'IRQ',
    'morocco': 'MAR', 'tunisia': 'TUN', 'algeria': 'ALG', 'egypt': 'EGY',
    'senegal': 'SEN', 'nigeria': 'NGA', 'ghana': 'GHA', 'cameroon': 'CMR',
    'ivory coast': 'CIV', 'cote d\'ivoire': 'CIV', "côte d'ivoire": 'CIV',
    'south africa': 'RSA',
  };
  return m[k] ?? s.substring(0, math.min(3, s.length)).toUpperCase();
}

// ─── Background overlays ─────────────────────────────────────────────────

/// Diagonal specular streak — soft white sweep that gives the card a
/// "laminated" sheen without overwhelming the photo below.
class _Specular extends StatelessWidget {
  const _Specular();
  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-1, -1),
            end: Alignment(1, 1),
            colors: [
              Color(0x14FFFFFF),
              Color(0x00FFFFFF),
              Color(0x00FFFFFF),
              Color(0x0AFFFFFF),
            ],
            stops: [0.0, 0.35, 0.7, 1.0],
          ),
        ),
      ),
    );
  }
}

class _HolographicSheen extends StatelessWidget {
  const _HolographicSheen({required this.theme});
  final RarityTheme theme;
  @override
  Widget build(BuildContext context) {
    final a = (theme.foilOpacity * 0.10).clamp(0.0, 0.15);
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: const Alignment(-0.8, -1),
            end: const Alignment(0.8, 0.2),
            colors: [
              theme.accentTint.withValues(alpha: a),
              Colors.transparent,
              theme.ratingColor.withValues(alpha: a * 0.6),
              Colors.transparent,
            ],
            stops: const [0.0, 0.35, 0.65, 1.0],
          ),
        ),
      ),
    );
  }
}

/// Inner hairline + outer rarity-tinted hairline. The two combined create a
/// "lifted" edge that separates the card from neighbours in a dense grid.
class _Frames extends StatelessWidget {
  const _Frames({required this.rarity, required this.tint});
  final CardRarity rarity;
  final Color tint;
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Outer rarity-tinted line
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tint.withValues(alpha: 0.30), width: 1),
            ),
          ),
          // Inner faint line
          Padding(
            padding: const EdgeInsets.all(4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Photo ───────────────────────────────────────────────────────────────

class _PlayerPhoto extends StatelessWidget {
  const _PlayerPhoto({
    required this.url,
    required this.lastName,
    required this.tint,
    required this.isCutout,
  });
  final String? url;
  final String lastName;
  final Color tint;

  /// True when the source is a TheSportsDB cutout PNG — already alpha-clean
  /// at high resolution. False (legacy api-football headshot) means we need
  /// the multiply-blend + radial mask hacks to suppress the white bg.
  final bool isCutout;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return _Initials(lastName: lastName);
    }

    if (isCutout) {
      // Cutout path — the player is the hero:
      //   - BoxFit.contain keeps the head intact regardless of source crop
      //     (TheSportsDB cutouts range from head-only to full-torso).
      //   - Alignment.bottomCenter anchors the player at the top of the
      //     name band, so heads of every player line up at the same waist
      //     height — gives a uniform "team sheet" feel across a grid.
      //   - high filterQuality matters here: cutouts are 2-3× larger than
      //     api-football headshots and we want crisp edges on a 220-px card.
      //
      // No shape-following body shadow: rendering a blurred-silhouette
      // duplicate of the player behind them reads as a *ghost twin*, not
      // a contact shadow — the silhouette is too distinct for it to fall
      // away as a ground occluder. The `_FloorGlow` painted under the
      // player (by the parent stack) handles the "stands on something"
      // sense of depth on its own.
      return CachedNetworkImage(
        imageUrl: url!,
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        filterQuality: FilterQuality.high,
        fadeInDuration: const Duration(milliseconds: 220),
        errorWidget: (_, __, ___) => _Initials(lastName: lastName),
        placeholder: (_, __) => const SizedBox.shrink(),
      );
    }

    // Legacy white-bg path — two tricks tame the api-football headshot:
    //   1. ColorBlendMode.multiply with a rarity-tinted near-white pulls
    //      #FFFFFF down toward the card accent so the bg doesn't punch.
    //   2. ShaderMask with a radial alpha fade dissolves the photo's outer
    //      ring into transparency so edges melt into the card gradient.
    final tintNearWhite = Color.lerp(Colors.white, tint, 0.22)!;
    final image = CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      fadeInDuration: const Duration(milliseconds: 220),
      color: tintNearWhite,
      colorBlendMode: BlendMode.multiply,
      errorWidget: (_, __, ___) => _Initials(lastName: lastName),
      placeholder: (_, __) => const SizedBox.shrink(),
    );
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const RadialGradient(
        center: Alignment(0, -0.1),
        radius: 0.95,
        colors: [Colors.black, Colors.black, Colors.transparent],
        stops: [0.0, 0.72, 1.0],
      ).createShader(rect),
      child: image,
    );
  }
}

/// Soft floor glow — a rarity-tinted horizontal ellipse painted at the
/// bottom-centre of the photo area, behind the player. Provides a sense of
/// the player "standing on" something instead of floating, and picks up the
/// card's accent so the photo feels integrated rather than collaged on.
class _FloorGlow extends StatelessWidget {
  const _FloorGlow({required this.tint});
  final Color tint;
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, 0.55),
        child: FractionallySizedBox(
          widthFactor: 0.85,
          heightFactor: 0.18,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  tint.withValues(alpha: 0.42),
                  tint.withValues(alpha: 0.10),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.lastName});
  final String lastName;
  @override
  Widget build(BuildContext context) {
    final code = lastName.isEmpty
        ? '·'
        : lastName.substring(0, math.min(2, lastName.length)).toUpperCase();
    return Center(
      child: Text(
        code,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 56,
          fontWeight: FontWeight.w800,
          color: Colors.white.withValues(alpha: 0.12),
          letterSpacing: -2.2,
        ),
      ),
    );
  }
}

// ─── Top chrome ──────────────────────────────────────────────────────────

class _LeagueTag extends StatelessWidget {
  const _LeagueTag({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontFamilyFallback: const ['SF Mono', 'Menlo', 'monospace'],
          fontSize: 6.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: Colors.white.withValues(alpha: 0.70),
          height: 1.0,
        ),
      ),
    );
  }
}

/// Serial-of-N chip floating above the bottom info band. Two-line layout
/// (#42 over "OF 250") keeps the eye on the unique number while still
/// signalling rarity. Border tinted by rarity so an iconic feels gilded.
class _SerialChip extends StatelessWidget {
  const _SerialChip({required this.serial, required this.total, required this.theme});
  final int serial;
  final int total;
  final RarityTheme theme;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.accentTint.withValues(alpha: 0.7), width: 1),
        boxShadow: [
          BoxShadow(color: theme.accentTint.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: -2),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '#$serial',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontFamilyFallback: const ['SF Mono', 'Menlo', 'monospace'],
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: theme.ratingColor,
              height: 1.0,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 1),
          Text(
            'OF $total',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontFamilyFallback: const ['SF Mono', 'Menlo', 'monospace'],
              fontSize: 6.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: theme.ratingColor.withValues(alpha: 0.7),
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Trophy count badge — small circle with a medal icon + the count. Shown
/// only when count > 0. Sits below the league tag on the top-left rail.
class _TrophyBadge extends StatelessWidget {
  const _TrophyBadge({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: AppColors.goldHairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, size: 9, color: AppColors.gold),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: AppColors.gold,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _Crest extends StatelessWidget {
  const _Crest({required this.url});
  final String url;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26, height: 26,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      padding: const EdgeInsets.all(3),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          fadeInDuration: const Duration(milliseconds: 180),
          errorWidget: (_, __, ___) => const SizedBox.shrink(),
          placeholder: (_, __) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// Hexagon rating badge — the prominent score pip Sorare puts under the
/// card; we surface it on the card itself top-left. Always painted in the
/// brand champagne-gold gradient so the rating reads consistently across
/// rarities and never fights the per-rarity card colour for attention.
class _HexRating extends StatelessWidget {
  const _HexRating({required this.rating, required this.color, required this.glow});
  final int rating;
  // Kept for API parity but ignored — the rating background is always gold.
  final Color color;
  final Color glow;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(color: AppColors.goldGlow, blurRadius: 14, spreadRadius: 0),
        ],
      ),
      child: ClipPath(
        clipper: const _HexClipper(),
        child: Container(
          width: 36, height: 40,
          decoration: const BoxDecoration(
            // Brand-gold gradient: highlight → mid → deep → mid.
            // The two highlights at top + lower-mid give the hex a polished
            // "minted coin" feel instead of a flat fill.
            gradient: LinearGradient(
              colors: [
                AppColors.goldSoft,
                AppColors.gold,
                AppColors.goldDeep,
                Color(0xFFA17A28),
              ],
              stops: [0.0, 0.35, 0.7, 1.0],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            // Thin inner hairline drawn via border-on-decoration — gives
            // the edge a forged-metal definition.
            border: Border.fromBorderSide(
              BorderSide(color: Color(0xFFFFEEC8), width: 0.8),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '$rating',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1.0,
              letterSpacing: -0.4,
              // Deep brown reads cleanly on the bright gold without
              // pulling toward pure black (which would look stamped on).
              color: Color(0xFF1E1308),
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

class _HexClipper extends CustomClipper<Path> {
  const _HexClipper();
  @override
  Path getClip(Size s) {
    final w = s.width, h = s.height;
    return Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.25)
      ..lineTo(w, h * 0.75)
      ..lineTo(w * 0.5, h)
      ..lineTo(0, h * 0.75)
      ..lineTo(0, h * 0.25)
      ..close();
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ─── Bottom block ────────────────────────────────────────────────────────

class _BottomBlock extends StatelessWidget {
  const _BottomBlock({
    required this.country,
    required this.position,
    required this.age,
    required this.firstName,
    required this.lastName,
    required this.editionLabel,
    required this.level,
    required this.accent,
  });
  final String country;
  final String? position;
  final int? age;
  final String firstName;
  final String lastName;
  final String? editionLabel;
  final int level;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        // The photo fades into this dark band — match the end colour so the
        // seam is invisible.
        gradient: LinearGradient(
          colors: [Color(0x00000000), Color(0xCC050608), Color(0xFF030406)],
          stops: [0.0, 0.35, 1.0],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _MetaStrip(country: country, position: position, age: age, accent: accent),
          const SizedBox(height: 6),
          if (firstName.isNotEmpty)
            Text(
              firstName.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
                color: Colors.white,
                height: 1.05,
              ),
            ),
          Text(
            lastName.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: Colors.white,
              height: 1.1,
            ),
          ),
          // 0..5 star row, right after the name. Hidden at level 0 so
          // unowned templates (no XP yet) don't show empty pips.
          if (level > 0) ...[
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 5; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Icon(
                      i < level ? Icons.star : Icons.star_outline,
                      size: 9,
                      color: i < level ? AppColors.gold : Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
              ],
            ),
          ],
          if (editionLabel != null) ...[
            const SizedBox(height: 3),
            Text(
              editionLabel!.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontFamilyFallback: const ['SF Mono', 'Menlo', 'monospace'],
                fontSize: 7,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
                color: Colors.white.withValues(alpha: 0.38),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact meta strip — value-only chips ([NZL] · FWD · 24). No labels;
/// space is the constraint, not legibility. `Flexible` cells let long
/// values truncate with ellipsis instead of overflowing the card.
class _MetaStrip extends StatelessWidget {
  const _MetaStrip({
    required this.country,
    required this.position,
    required this.age,
    required this.accent,
  });
  final String country;
  final String? position;
  final int? age;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final hasCountry = country.isNotEmpty;
    final hasPos = position != null && position!.isNotEmpty && position != '—';
    final hasAge = age != null && age! > 0;
    if (!hasCountry && !hasPos && !hasAge) return const SizedBox.shrink();
    final cells = <Widget>[];
    if (hasCountry) cells.add(_MetaChip(text: country, color: accent));
    if (hasPos) cells.add(_MetaChip(text: position!.toUpperCase(), color: accent));
    if (hasAge) cells.add(_MetaChip(text: '${age}Y', color: accent));
    return Row(
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Flexible(child: cells[i]),
        ],
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.32)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontFamilyFallback: const ['SF Mono', 'Menlo', 'monospace'],
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: color,
          height: 1.0,
        ),
      ),
    );
  }
}

// ─── Compact card (used on the lineup-builder pitch) ─────────────────────

/// `MiniPCard` — slim, fixed-width variant that strips away non-essentials.
/// Used in dense layouts where a full PCard would overwhelm: the pitch tile
/// stack, leaderboard rows, compact carousels.
class MiniPCard extends StatelessWidget {
  const MiniPCard({
    super.key,
    required this.rarity,
    this.photoUrl,
    this.lastName,
    this.country,
    this.position,
    this.clubCrestUrl,
    this.onTap,
    this.height = 88,
    this.heroTag,
    this.glow = false,
  });

  final CardRarity rarity;
  final String? photoUrl;
  final String? lastName;
  final String? country;
  final String? position;
  final String? clubCrestUrl;
  final VoidCallback? onTap;
  final double height;
  final Object? heroTag;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final theme = RarityTheme.of(rarity);
    final width = height * 0.66;
    Widget card = AspectRatio(
      aspectRatio: 0.66,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: glow
              ? const [BoxShadow(color: AppColors.goldGlow, blurRadius: 16, spreadRadius: 1)]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(decoration: BoxDecoration(gradient: theme.cardGradient)),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.85),
                    radius: 1.0,
                    colors: [
                      theme.accentTint.withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.7],
                  ),
                ),
              ),
              const _Specular(),
              Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: theme.accentTint.withValues(alpha: 0.28)),
                ),
              ),
              // Floor glow (cutout only — see PCard for the rationale).
              if (PCard._isCutout(photoUrl)) _FloorGlow(tint: theme.accentTint),
              // Photo. Cutouts get a near-full-bleed bottom-anchored frame
              // so the player fills the chip; white-bg legacy photos stay
              // in a small centred box to avoid revealing the seam.
              Positioned.fill(
                child: Padding(
                  padding: PCard._isCutout(photoUrl)
                      ? const EdgeInsets.fromLTRB(2, 4, 2, 24)
                      : const EdgeInsets.fromLTRB(4, 6, 4, 30),
                  child: _PlayerPhoto(
                    url: photoUrl,
                    lastName: lastName ?? '',
                    tint: theme.accentTint,
                    isCutout: PCard._isCutout(photoUrl),
                  ),
                ),
              ),
              // Crest top-right
              if (clubCrestUrl != null)
                Positioned(
                  top: 4, right: 4,
                  child: SizedBox(width: 16, height: 16, child: _Crest(url: clubCrestUrl!)),
                ),
              // Name + meta band
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0x00000000), Color(0xFF050608)],
                      stops: [0.0, 0.65],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        (lastName ?? '').toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.15,
                          height: 1.05,
                        ),
                      ),
                      if ((position ?? '').isNotEmpty || (country ?? '').isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          [
                            if ((position ?? '').isNotEmpty) position!.toUpperCase(),
                            if ((country ?? '').isNotEmpty) _iso3(country),
                          ].join(' · '),
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontFamilyFallback: const ['SF Mono', 'Menlo', 'monospace'],
                            fontSize: 6.5,
                            fontWeight: FontWeight.w700,
                            color: theme.ratingColor.withValues(alpha: 0.85),
                            letterSpacing: 0.8,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    card = SizedBox(width: width, height: height, child: card);
    if (heroTag != null) {
      card = Hero(tag: heroTag!, child: Material(color: Colors.transparent, child: card));
    }
    if (onTap == null) return card;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: card);
  }
}
