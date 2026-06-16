import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_colors.dart';
import '../../core/router/route_paths.dart';
import '../../core/widgets/eyebrow.dart';
import '../../core/widgets/premium_image.dart';
import '../../core/widgets/skeleton.dart';
import '../scores/data/models/match_dto.dart';
import 'highlight_link.dart';
import 'highlights_providers.dart';
import 'youtube_embed.dart';

/// Browseable list of finished matches with a FIFA-official highlight.
class HighlightsScreen extends ConsumerWidget {
  const HighlightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(highlightsProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onBack: () => context.canPop() ? context.pop() : context.go(RoutePaths.home)),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.gold,
                backgroundColor: AppColors.surface,
                onRefresh: () async => ref.refresh(highlightsProvider.future),
                child: async.when(
                  loading: () => ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: const [
                      Skeleton(height: 96, radius: 14),
                      SizedBox(height: 12),
                      Skeleton(height: 96, radius: 14),
                      SizedBox(height: 12),
                      Skeleton(height: 96, radius: 14),
                    ],
                  ),
                  error: (_, __) => const _Message(
                    icon: Icons.wifi_off_rounded,
                    title: 'Couldn’t load highlights',
                    subtitle: 'Pull to refresh and try again.',
                  ),
                  data: (matches) {
                    if (matches.isEmpty) {
                      return const _Message(
                        icon: Icons.play_circle_outline,
                        title: 'No highlights yet',
                        subtitle: 'Match highlights appear here once full time is played.',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: matches.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _HighlightCard(match: matches[i]),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 16, 8),
      child: Row(
        children: [
          IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back, color: AppColors.fg)),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Eyebrow('FIFA WORLD CUP 2026™', gold: true, size: 9),
              SizedBox(height: 2),
              Text(
                'Highlights',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.fg,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.match});
  final MatchDto match;
  @override
  Widget build(BuildContext context) {
    final thumb = youtubeThumb(match.highlightUrl);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => openHighlight(context, match),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.goldHairline.withValues(alpha: 0.5)),
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1815), Color(0xFF110F0D)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Row(
          children: [
            // Thumbnail with a play badge.
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
              child: SizedBox(
                width: 128,
                height: 96,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PremiumImage(url: thumb, fit: BoxFit.cover),
                    Container(color: Colors.black.withValues(alpha: 0.18)),
                    const Center(
                      child: Icon(Icons.play_circle_fill, color: Colors.white, size: 34),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${match.homeTeam.shortName ?? match.homeTeam.name} ${match.homeScore}–${match.awayScore} ${match.awayTeam.shortName ?? match.awayTeam.name}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.fg,
                        height: 1.25,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Eyebrow('FULL TIME', size: 9),
                        const SizedBox(width: 8),
                        Text(
                          _dateLabel(match.kickoffAt),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _dateLabel(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final d = dt.toLocal();
    return '${d.day} ${months[d.month - 1]}';
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(icon, size: 48, color: AppColors.muted),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.fg,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.muted, height: 1.4),
          ),
        ),
      ],
    );
  }
}
