import 'package:flutter/material.dart';

/// Pulsing red "LIVE" badge — shown when at least one match in the gameweek
/// is being scored in real time.
class LiveBadge extends StatefulWidget {
  const LiveBadge({super.key, this.label = 'LIVE'});
  final String label;

  @override
  State<LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.16 + 0.20 * t),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.45 + 0.45 * t),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.7 + 0.3 * t),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.red.shade300,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
