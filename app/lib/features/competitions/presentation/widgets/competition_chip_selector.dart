import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/competitions_repository.dart';

/// Horizontal chip selector for filtering by competition.
/// **Auto-hides when only one competition exists** — so the WC-only ship
/// doesn't show a useless single-chip row.
class CompetitionChipSelector extends ConsumerWidget {
  const CompetitionChipSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(competitionsProvider);
    return async.maybeWhen(
      data: (competitions) {
        if (competitions.length <= 1) return const SizedBox.shrink();
        final selected = ref.watch(selectedCompetitionProvider);
        return _ChipsRow(
          competitions: competitions,
          selected: selected,
          onChanged: (id) => ref.read(selectedCompetitionProvider.notifier).set(id),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _ChipsRow extends StatelessWidget {
  const _ChipsRow({required this.competitions, required this.selected, required this.onChanged});
  final List competitions;
  final String? selected;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: competitions.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == 0) {
            return _Chip(
              label: 'All',
              isSelected: selected == null,
              onTap: () => onChanged(null),
            );
          }
          final c = competitions[i - 1];
          return _Chip(
            label: c.name,
            iconUrl: c.emblemUrl,
            isSelected: selected == c.id,
            isLive: c.isLive,
            onTap: () => onChanged(c.id),
          );
        },
      ),
    ).animate().fade(duration: 220.ms).slideY(begin: -0.1, end: 0);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.isSelected, required this.onTap,
               this.iconUrl, this.isLive = false});
  final String label;
  final bool isSelected, isLive;
  final String? iconUrl;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (iconUrl != null) ...[
                  CachedNetworkImage(imageUrl: iconUrl!, width: 18, height: 18,
                      errorWidget: (_, __, ___) => const SizedBox(width: 18, height: 18)),
                  const SizedBox(width: 6),
                ],
                Text(label, style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                )),
                if (isLive) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
