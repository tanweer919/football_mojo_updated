import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/router/route_paths.dart';

/// `.tabbar` from `components.css` — floating pill, backdrop-blurred,
/// 5 destinations, gold active state.
///
/// Sits 24px above the system gesture bar with safe-area padding added
/// on top.
class PitchTabbar extends ConsumerWidget {
  const PitchTabbar({super.key});

  static const _items = <_Dest>[
    _Dest('Home',      _IconHome(),      RoutePaths.home),
    _Dest('World Cup', _IconWorldCup(),  RoutePaths.tournament),
    _Dest('Fantasy',   _IconFantasy(),   RoutePaths.fantasyHome),
    // Tab opens the public marketplace browse. The "Collection" affordance
    // in the market header lets signed-in users jump into their album.
    _Dest('Cards',     _IconCards(),     RoutePaths.market),
    _Dest('You',       _IconYou(),       RoutePaths.profile),
  ];

  int _indexFor(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final i = _items.indexWhere((d) => loc.startsWith(d.path));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = _indexFor(context);
    final bottom = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottom > 0 ? bottom + 6 : 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: _buildBar(context, active),
        ),
      ),
    );
  }

  Widget _buildBar(BuildContext context, int active) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: const Color(0xD9201E1B),
            border: Border.all(color: AppColors.borderSoft, width: 1),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 32,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Row(
            children: List.generate(_items.length, (i) {
              final d = _items[i];
              final isActive = i == active;
              return Expanded(
                child: _TabItem(
                  label: d.label,
                  icon: d.icon,
                  active: isActive,
                  onTap: () => context.go(d.path),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _Dest {
  const _Dest(this.label, this.icon, this.path);
  final String label;
  final Widget icon;
  final String path;
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });
  final String label;
  final Widget icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.gold : AppColors.muted2;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: active ? const Color(0x331E1A14) : Colors.transparent,
        ),
        // Constrain the inner column to the available height — the tabbar
        // shell is 64px tall with 4+4 margin, leaving 56-8 (padding) = 48px
        // for icon + label. Without this clamp, the 22-px icon + 4-px gap +
        // 11-px text line height + descenders overflows by ~2-4px.
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTheme(
              data: IconThemeData(color: color, size: 20),
              child: icon,
            ),
            const SizedBox(height: 2),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontFamilyFallback: const ['SF Mono', 'Menlo', 'monospace'],
                fontSize: 9,
                height: 1.0,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.72,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Icon glyphs — match the SVGs in `android/home.html` exactly using Flutter Icons.
class _IconHome extends StatelessWidget {
  const _IconHome();
  @override
  Widget build(BuildContext context) => const Icon(Icons.home_outlined);
}
class _IconWorldCup extends StatelessWidget {
  const _IconWorldCup();
  @override
  Widget build(BuildContext context) => const Icon(Icons.public);
}
class _IconFantasy extends StatelessWidget {
  const _IconFantasy();
  @override
  Widget build(BuildContext context) => const Icon(Icons.shield_outlined);
}
class _IconCards extends StatelessWidget {
  const _IconCards();
  @override
  Widget build(BuildContext context) => const Icon(Icons.style_outlined);
}
class _IconYou extends StatelessWidget {
  const _IconYou();
  @override
  Widget build(BuildContext context) => const Icon(Icons.person_outline);
}
