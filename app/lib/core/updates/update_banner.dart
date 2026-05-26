import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'app_updates_service.dart';

/// Top-of-screen banner. Renders nothing in idle/force states (force is
/// handled by [ForceUpdateGate]), or a coloured Material 3 banner when a
/// Shorebird patch / store update is available.
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<UpdateStatus>(
      valueListenable: AppUpdatesService.status,
      builder: (context, status, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) =>
              SizeTransition(sizeFactor: anim, axisAlignment: -1, child: FadeTransition(opacity: anim, child: child)),
          child: switch (status) {
            UpdateIdle()         => const SizedBox.shrink(key: ValueKey('idle')),
            UpdateForceRequired() => const SizedBox.shrink(key: ValueKey('force')),    // handled by ForceUpdateGate
            UpdatePatchReady() => _Banner(
                key: const ValueKey('patch'),
                color: theme.colorScheme.primaryContainer,
                onColor: theme.colorScheme.onPrimaryContainer,
                icon: Icons.bolt,
                title: 'Update ready',
                subtitle: 'Restart to apply the latest improvements.',
              ),
            UpdateRecommended(:final target) => _Banner(
                key: const ValueKey('recommended'),
                color: theme.colorScheme.tertiaryContainer,
                onColor: theme.colorScheme.onTertiaryContainer,
                icon: Icons.system_update,
                title: 'Version $target available',
                subtitle: 'Tap to update on the store.',
                onTap: AppUpdatesService.openStore,
              ),
          },
        );
      },
    );
  }
}

/// Full-screen blocking gate for forced updates. Wrap MaterialApp.router in
/// this — when the gate fires, nothing else is reachable until the user updates.
class ForceUpdateGate extends StatelessWidget {
  const ForceUpdateGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UpdateStatus>(
      valueListenable: AppUpdatesService.status,
      builder: (context, status, _) {
        if (status is! UpdateForceRequired) return child;
        return _ForceScreen(status: status);
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    super.key,
    required this.color,
    required this.onColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
  final Color color, onColor;
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      child: InkWell(
        onTap: onTap,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(
              children: [
                Icon(icon, color: onColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(color: onColor, fontWeight: FontWeight.w800)),
                      Text(subtitle, style: TextStyle(color: onColor.withValues(alpha: 0.85), fontSize: 12)),
                    ],
                  ),
                ),
                if (onTap != null) Icon(Icons.chevron_right, color: onColor),
              ],
            ),
          ),
        ),
      ),
    ).animate().slideY(begin: -0.6, end: 0, duration: 320.ms, curve: Curves.easeOutCubic);
  }
}

class _ForceScreen extends StatelessWidget {
  const _ForceScreen({required this.status});
  final UpdateForceRequired status;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.system_update, size: 96, color: theme.colorScheme.primary),
                  const SizedBox(height: 24),
                  Text('Update required',
                      style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(status.message,
                      textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 4),
                  Text('Installed ${status.installed} · required ${status.required}',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    icon: const Icon(Icons.download),
                    onPressed: AppUpdatesService.openStore,
                    label: const Text('Update on the store'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
