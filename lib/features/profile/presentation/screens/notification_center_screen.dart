import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/profile_repository.dart';

/// Notification inbox. Renders the user's full push history with read-state
/// styling, category filter chips, tap-to-route deeplinks. Marks all read
/// on first frame so the bell badge clears as soon as the user opens it.
class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});
  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    // Mark everything read on screen open — matches user expectation
    // ("I saw it"). Fired post-frame so the unread state is visible for
    // one paint cycle, then the badge clears.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(profileRepositoryProvider).markRead(all: true);
        ref.invalidate(unreadNotificationCountProvider);
      } catch (_) {
        // Non-fatal — read state will catch up on the next visit.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inbox = ref.watch(inboxProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Notification settings',
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => context.push('/profile/notifications'),
          ),
        ],
      ),
      body: inbox.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (page) {
          if (page.items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_off_outlined,
                        size: 40, color: theme.colorScheme.outline),
                    const SizedBox(height: 12),
                    Text(
                      'No notifications yet.',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Follow teams and pick a country you support to start hearing from the World Cup.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          final filtered = _categoryFilter == null
              ? page.items
              : page.items.where((i) => i.category == _categoryFilter).toList();
          return Column(
            children: [
              _FilterStrip(
                items: page.items,
                selected: _categoryFilter,
                onChanged: (c) => setState(() => _categoryFilter = c),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(inboxProvider);
                    ref.invalidate(unreadNotificationCountProvider);
                  },
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => _InboxRow(item: filtered[i])
                        .animate()
                        .fade(duration: 200.ms, delay: (15 * i.clamp(0, 12)).ms),
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

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.items,
    required this.selected,
    required this.onChanged,
  });
  final List<InboxItem> items;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    // Derive chips from categories present in the page — no empty filters.
    final categories = <String>{
      for (final i in items)
        if (i.category != null) i.category!,
    }.toList()
      ..sort();
    if (categories.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _Chip(
            label: 'All',
            selected: selected == null,
            onTap: () => onChanged(null),
          ),
          for (final c in categories)
            _Chip(
              label: _humanCategory(c),
              selected: selected == c,
              onTap: () => onChanged(c),
            ),
        ],
      ),
    );
  }

  static String _humanCategory(String raw) {
    switch (raw) {
      case 'matchGoals': return 'Goals';
      case 'matchKickoff': return 'Kick-offs';
      case 'matchFulltime': return 'Full-time';
      case 'matchLineup': return 'Lineups';
      case 'breakingNews': return 'Breaking';
      case 'wcDailyRecap': return 'WC recap';
      case 'fantasyResults': return 'Fantasy';
      case 'h2hInvites': return '1v1 invites';
      case 'h2hResults': return '1v1 results';
      case 'cardDrops': return 'Cards';
      default: return raw;
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: selected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InboxRow extends StatelessWidget {
  const _InboxRow({required this.item});
  final InboxItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = !item.isRead;
    return Material(
      color: unread
          ? theme.colorScheme.primary.withValues(alpha: 0.06)
          : Colors.transparent,
      child: InkWell(
        onTap: item.deepLink == null ? null : () => _follow(context, item.deepLink!),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CategoryDot(category: item.category),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title ?? '(no title)',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 14,
                              height: 1.3,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (item.body != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.body!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _relative(item.sentAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _follow(BuildContext context, String deepLink) {
    const prefix = 'footballmojo://';
    if (!deepLink.startsWith(prefix)) return;
    final path = '/${deepLink.substring(prefix.length)}';
    context.push(path);
  }

  static String _relative(DateTime t) {
    final diff = DateTime.now().difference(t.toLocal());
    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}

class _CategoryDot extends StatelessWidget {
  const _CategoryDot({this.category});
  final String? category;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = switch (category) {
      'matchGoals' || 'matchFulltime' || 'matchKickoff' || 'matchLineup' =>
        (Icons.sports_soccer_rounded, Colors.greenAccent),
      'breakingNews' || 'wcDailyRecap' =>
        (Icons.newspaper_rounded, Colors.lightBlueAccent),
      'fantasyResults' =>
        (Icons.leaderboard_rounded, theme.colorScheme.primary),
      'h2hInvites' || 'h2hResults' =>
        (Icons.sports_kabaddi_rounded, Colors.orangeAccent),
      'cardDrops' => (Icons.style_rounded, Colors.purpleAccent),
      _ => (Icons.notifications_rounded, theme.colorScheme.onSurfaceVariant),
    };
    return CircleAvatar(
      radius: 18,
      backgroundColor: color.withValues(alpha: 0.18),
      child: Icon(icon, color: color, size: 18),
    );
  }
}
