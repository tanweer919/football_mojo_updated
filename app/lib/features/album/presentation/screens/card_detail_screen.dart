import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/motion.dart';
import '../../../../core/design/rarity_theme.dart';
import '../../../../core/deeplink/chottu_link_service.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/foil_overlay.dart';
import '../../../../core/widgets/premium_image.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../data/models/card_models.dart';
import '../../data/repositories/album_repository.dart';

/// Normalise a raw player position code (api-football uses GK/DF/MF/FW; the
/// fantasy layer uses GK/DEF/MID/FWD) to a short 2-3 letter badge label.
String _positionShort(String p) => switch (p.toUpperCase()) {
      'GK' => 'GK',
      'DF' || 'DEF' || 'D' => 'DEF',
      'MF' || 'MID' || 'M' => 'MID',
      'FW' || 'FWD' || 'F' || 'ATT' => 'FWD',
      _ => p.toUpperCase(),
    };

/// Full position word for the card back.
String _positionLong(String p) => switch (_positionShort(p)) {
      'GK' => 'Goalkeeper',
      'DEF' => 'Defender',
      'MID' => 'Midfielder',
      'FWD' => 'Forward',
      final s => s,
    };

/// Premium card detail. Top half is a 3D-tilted player card with foil/holo
/// overlay, drag the card to tilt, tap to flip, with rarity-driven background
/// gradient that fills the entire screen.
class CardDetailScreen extends ConsumerStatefulWidget {
  const CardDetailScreen({super.key, required this.ownedCardId});
  final String ownedCardId;
  @override
  ConsumerState<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends ConsumerState<CardDetailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip;
  late final Future<OwnedCardDto> _future;
  bool _showBack = false;
  Offset _tilt = Offset.zero;

  @override
  void initState() {
    super.initState();
    _flip = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _future = ref.read(albumRepositoryProvider).ownedById(widget.ownedCardId);
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  void _onTap() {
    setState(() => _showBack = !_showBack);
    _showBack ? _flip.forward() : _flip.reverse();
  }

  void _onPan(DragUpdateDetails d) {
    setState(() {
      _tilt += Offset(d.delta.dx / 60, d.delta.dy / 60);
      _tilt = Offset(_tilt.dx.clamp(-0.5, 0.5), _tilt.dy.clamp(-0.5, 0.5));
    });
  }

  void _onPanEnd(_) {
    setState(() => _tilt = Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          FutureBuilder<OwnedCardDto>(
            future: _future,
            builder: (_, snap) {
              final card = snap.data;
              if (card == null) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Share',
                icon: const Icon(Icons.ios_share_rounded, color: Colors.white),
                onPressed: () {
                  // Share player card with ChottuLink deep link.
                  final playerName = card.template.playerName ?? card.template.edition;
                  ChottuLinkService.instance.sharePlayer(
                    playerId: card.template.id,
                    playerName: playerName,
                    photoUrl: card.template.artUrl.isNotEmpty ? card.template.artUrl : null,
                    teamName: card.template.teamName,
                  );
                },
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<OwnedCardDto>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: Skeleton(height: 480, width: 320, radius: 28));
          }
          if (snap.hasError) {
            return ErrorView(message: '${snap.error}', onRetry: () => setState(() {}));
          }
          final card = snap.data!;
          final theme = RarityTheme.of(card.template.rarity);
          return Stack(
            fit: StackFit.expand,
            children: [
              // Background — full-bleed rarity gradient.
              DecoratedBox(
                decoration: BoxDecoration(gradient: theme.gradient),
              ),
              // Floodlight glow.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Color(0x44FFFFFF), Color(0x00FFFFFF)],
                    radius: 0.7,
                    center: Alignment(0, -0.4),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
                  child: Column(
                    children: [
                      const SizedBox(height: 48),
                      Expanded(
                        child: Center(
                          child: GestureDetector(
                            onTap: _onTap,
                            onPanUpdate: _onPan,
                            onPanEnd: _onPanEnd,
                            child: AnimatedBuilder(
                              animation: _flip,
                              builder: (_, __) {
                                final value = AppMotion.swap.transform(_flip.value);
                                final angle = value * math.pi;
                                final isBack = value > 0.5;
                                return Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, 0.0012)
                                    ..rotateY(angle + _tilt.dx)
                                    ..rotateX(-_tilt.dy),
                                  child: isBack
                                      ? Transform(
                                          transform: Matrix4.identity()..rotateY(math.pi),
                                          alignment: Alignment.center,
                                          child: _Back(card: card, theme: theme),
                                        )
                                      : _Front(card: card, theme: theme),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      _Footer(card: card, theme: theme, showingBack: _showBack),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Front extends StatelessWidget {
  const _Front({required this.card, required this.theme});
  final OwnedCardDto card;
  final RarityTheme theme;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: AspectRatio(
        aspectRatio: 0.68,
        child: FoilOverlay(
          rarity: theme,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.xxl),
              gradient: theme.gradient,
              border: Border.all(color: theme.frame, width: 2),
              boxShadow: [
                BoxShadow(color: theme.glow, blurRadius: 40, spreadRadius: -4),
                BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 16)),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Inner frame ring.
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                      border: Border.all(color: theme.frame.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
                // Backdrop glow + photo.
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 36, 18, 110),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              theme.accent.withValues(alpha: 0.45),
                              Colors.transparent,
                            ],
                            radius: 0.95,
                            center: const Alignment(0, -0.1),
                          ),
                        ),
                      ),
                      // Player art when present and it loads; otherwise a
                      // clear crest-style placeholder (covers empty AND
                      // broken/404 URLs) instead of a blank/cyan panel.
                      PremiumImage(
                        url: card.template.artUrl,
                        fit: BoxFit.contain,
                        fallback: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sports_soccer,
                                  size: 96, color: theme.accent.withValues(alpha: 0.8)),
                              const SizedBox(height: 10),
                              Text(
                                (card.template.playerName ?? card.template.edition)
                                    .toUpperCase(),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.frame,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Top ribbon (rarity)
                Positioned(
                  top: 14, left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: theme.accent.withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      theme.label.toUpperCase(),
                      style: TextStyle(
                        color: theme.accent,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ),
                ),
                // Top-right serial
                Positioned(
                  top: 14, right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#${card.serialNumber}/${card.template.totalSupply}',
                      style: TextStyle(
                        color: theme.frame,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                // Bottom name plate
                Positioned(
                  left: 14, right: 14, bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (card.template.playerName ?? 'Player').toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          letterSpacing: -0.4,
                          height: 1.0,
                        ),
                      ),
                      if (card.template.position != null || card.template.teamName != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (card.template.position != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: theme.accent.withValues(alpha: 0.6)),
                                ),
                                child: Text(
                                  _positionShort(card.template.position!),
                                  style: TextStyle(
                                    color: theme.accent,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (card.template.teamName != null)
                              Flexible(
                                child: Text(
                                  card.template.teamName!.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: theme.accent,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Iconic signature stroke
                if (theme.signature != null)
                  Positioned(
                    bottom: 14, right: 14,
                    child: Text(
                      theme.signature!,
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontStyle: FontStyle.italic,
                        color: theme.accent.withValues(alpha: 0.85),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Back extends StatelessWidget {
  const _Back({required this.card, required this.theme});
  final OwnedCardDto card;
  final RarityTheme theme;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: AspectRatio(
        aspectRatio: 0.68,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.xxl),
            gradient: theme.gradient,
            border: Border.all(color: theme.frame, width: 2),
            boxShadow: [
              BoxShadow(color: theme.glow, blurRadius: 40, spreadRadius: -4),
              BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 16)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  'PROVENANCE',
                  style: TextStyle(
                    color: theme.accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                (card.template.playerName ?? 'Player'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  height: 1.05,
                  letterSpacing: -0.4,
                ),
              ),
              if (card.template.teamName != null)
                Text(
                  card.template.teamName!,
                  style: TextStyle(
                    color: theme.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              const Spacer(),
              if (card.template.position != null)
                _Row(label: 'Position', value: _positionLong(card.template.position!), theme: theme),
              _Row(label: 'Edition', value: card.template.edition, theme: theme),
              _Row(label: 'Rarity', value: theme.label, theme: theme),
              _Row(label: 'Serial', value: '#${card.serialNumber} of ${card.template.totalSupply}', theme: theme),
              _Row(
                label: 'Minted',
                value: '${card.mintedAt.toLocal().year}-'
                    '${card.mintedAt.toLocal().month.toString().padLeft(2, '0')}-'
                    '${card.mintedAt.toLocal().day.toString().padLeft(2, '0')}',
                theme: theme,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, required this.theme});
  final String label;
  final String value;
  final RarityTheme theme;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: theme.frame.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.card, required this.theme, required this.showingBack});
  final OwnedCardDto card;
  final RarityTheme theme;
  final bool showingBack;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        children: [
          Text(
            showingBack ? 'Tap card to flip back' : 'Tap card to flip · drag to tilt',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Edition ${card.template.edition}',
            style: TextStyle(
              color: theme.accent,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    ).animate().fade(duration: AppMotion.md, delay: 200.ms);
  }
}
