import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/bootstrap/deferred_bootstrap.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/widgets/pitch_scaffold.dart';
import '../widgets/pitch_tabbar.dart';

/// Shell that overlays the floating PITCH tabbar on top of the routed screen.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) runDeferredBootstrap(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final hideTabbar = loc == RoutePaths.market || loc == RoutePaths.fantasyHome;

    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBody: true,
      body: Stack(
        children: [
          // Centre + clamp on tablet/desktop so screens never span absurdly
          // wide. Phones (mobile breakpoint) pass through unchanged.
          Positioned.fill(
            child: CenteredContent(
              maxWidth: context.isMobile ? double.infinity : 540,
              child: TabShellScope(child: widget.child),
            ),
          ),
          if (!hideTabbar)
            const Positioned(
              left: 0, right: 0, bottom: 0,
              child: PitchTabbar(),
            ),
        ],
      ),
    );
  }
}
