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
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final bottomInset = withinTabShell ? 110.0 : 24.0;

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

    final inner = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: topInset),
        header,
        Flexible(child: child),
        SizedBox(height: bottomInset),
      ],
    );

    // Wrap in Scaffold so descendant Text widgets have the Material ancestor
    // they need (otherwise Flutter draws the double-underline "missing
    // dependency" error indicator). Background still painted explicitly
    // because some screens render full-bleed gradients above it.
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: scrollable
          ? SingleChildScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height,
                child: inner,
              ),
            )
          : inner,
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
