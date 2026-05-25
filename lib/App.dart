import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/bootstrap/deferred_bootstrap.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/updates/app_updates_service.dart';
import 'core/updates/update_banner.dart';

class FootballMojoApp extends ConsumerStatefulWidget {
  const FootballMojoApp({super.key});
  @override
  ConsumerState<FootballMojoApp> createState() => _FootballMojoAppState();
}

class _FootballMojoAppState extends ConsumerState<FootballMojoApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Release the native launch splash now that Flutter has mounted its widget
    // tree — the first frame will paint immediately after. Eliminates the
    // OS-splash → white-flash → Flutter-splash sequence.
    WidgetsBinding.instance.addPostFrameCallback((_) => FlutterNativeSplash.remove());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check on resume — long-backgrounded apps may have a patch waiting,
    // a newer version published, or a min-version bump pushed via Remote Config.
    if (state == AppLifecycleState.resumed) {
      AppUpdatesService.checkAll();
      inAppUpdateService.check();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final mode = ref.watch(themeModeProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp.router(
          title: 'FootballMojo',
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          theme: AppTheme.light(lightDynamic),
          darkTheme: AppTheme.dark(darkDynamic),
          themeMode: mode,
          // Forced updates take over the screen completely; recommended/patch
          // updates show as a slim banner above the routed body.
          builder: (context, child) {
            return ForceUpdateGate(
              child: Column(
                children: [
                  const UpdateBanner(),
                  Expanded(child: child ?? const SizedBox.shrink()),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
