import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import 'eyebrow.dart';
import 'pitch_buttons.dart';

/// Standard secondary-screen scaffold matching the spec's `.topbar` pattern:
/// back button (or none) · gold-mono title · trailing icon button (or none).
///
/// Wraps the body in a SingleChildScrollView with bottom padding so the
/// floating tabbar from [HomeShell] doesn't cover content.
class PitchScreen extends StatelessWidget {
  const PitchScreen({
    super.key,
    required this.title,
    required this.child,
    this.onBack,
    this.trailing,
    this.withinTabShell = true,
    this.scrollable = true,
  });

  final String title;
  final Widget child;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool withinTabShell;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    // Reserve space for the system status bar at the top, the floating
    // tabbar (when in shell) plus the OS gesture-pill / 3-button bar at
    // the bottom. With edge-to-edge mode enabled in main.dart the Scaffold
    // background paints all the way under both — so the `bg` colour fills
    // every pixel and there's no black band.
    final topInset = viewPadding.top;
    final bottomGesture = viewPadding.bottom;
    final bottomInset = (withinTabShell ? 110.0 : 0.0) + bottomGesture + 16;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Row(
        children: [
          if (onBack != null)
            CircleIconButton(icon: Icons.chevron_left, onPressed: onBack)
          else
            const SizedBox(width: 36),
          Expanded(
            child: Center(child: Eyebrow(title, gold: true, size: 11)),
          ),
          trailing ?? const SizedBox(width: 36),
        ],
      ),
    );

    return Scaffold(
      // extendBody so the body ColoredBox paints under the gesture pill /
      // 3-button bar instead of leaving an OS-default black band.
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: topInset),
          header,
          Expanded(
            child: scrollable
                ? SingleChildScrollView(
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: bottomInset),
                      child: child,
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.only(bottom: bottomInset),
                    child: child,
                  ),
          ),
        ],
      ),
    );
  }
}

/// `.sect-head` from spec — title + optional gold action eyebrow on the right.
class SectionHead extends StatelessWidget {
  const SectionHead({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(20, 24, 20, 14),
  });
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.26,
              color: AppColors.fg,
            ),
          ),
          const Spacer(),
          if (action != null)
            GestureDetector(onTap: onAction, child: Eyebrow(action!, gold: true)),
        ],
      ),
    );
  }
}
