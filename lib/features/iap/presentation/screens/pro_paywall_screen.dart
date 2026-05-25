import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../data/iap_service.dart';

class ProPaywallScreen extends ConsumerWidget {
  const ProPaywallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isPro = ref.watch(isProActiveProvider);
    final products = ref.watch(iapProductsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('FootballMojo Pro')),
      body: CenteredContent(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _Hero(active: isPro).animate().fade(duration: 320.ms).slideY(begin: 0.04, end: 0),
            const SizedBox(height: 20),
            const _Feature(icon: Icons.block,             title: 'Ad-free experience'),
            const _Feature(icon: Icons.bolt,              title: 'Instant goal alerts (priority push)'),
            const _Feature(icon: Icons.insights,          title: 'Advanced stats — xG, heatmaps, pass maps'),
            const _Feature(icon: Icons.history,           title: 'Historical season data + H2H archive'),
            const _Feature(icon: Icons.bookmark_outline,  title: 'Offline news saves'),
            const _Feature(icon: Icons.workspace_premium, title: 'Pro frame for every card you mint'),
            const SizedBox(height: 20),
            products.when(
              loading: () => const SkeletonList(itemHeight: 80),
              error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(iapProductsProvider)),
              data: (list) {
                final subs = list.where((p) =>
                    p.id == IapCatalog.proMonthly || p.id == IapCatalog.proYearly).toList();
                if (subs.isEmpty) {
                  return Card(
                    color: theme.colorScheme.surfaceContainerHigh,
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Subscriptions are loading — make sure you’re signed into the App Store / Play Store.',
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final p in subs) _Plan(product: p),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () async {
                  final svc = await ref.read(iapServiceProvider.future);
                  await svc.restorePurchases();
                },
                child: const Text('Restore purchases'),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Subscriptions auto-renew until cancelled in App Store / Play Store settings. Cancel any time. No refunds for partial periods.',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.workspace_premium, size: 40, color: theme.colorScheme.onPrimary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(active ? 'You’re Pro' : 'Upgrade to Pro',
                    style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  active
                      ? 'Thanks for supporting FootballMojo.'
                      : 'Faster alerts, no ads, deeper stats. Cancel any time.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onPrimary.withValues(alpha: 0.9)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.title});
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
        ],
      ),
    );
  }
}

class _Plan extends ConsumerWidget {
  const _Plan({required this.product});
  final ProductDetails product;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final yearly = product.id == IapCatalog.proYearly;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(yearly ? 'Yearly' : 'Monthly',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        if (yearly) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text('SAVE',
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ],
                    ),
                    Text(product.price,
                        style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () async {
                  final svc = await ref.read(iapServiceProvider.future);
                  await svc.purchaseSubscription(product);
                },
                child: const Text('Subscribe'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
