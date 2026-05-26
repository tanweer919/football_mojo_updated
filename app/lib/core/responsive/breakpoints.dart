import 'package:flutter/widgets.dart';

enum Breakpoint { mobile, tablet, desktop }

extension BreakpointX on BuildContext {
  Breakpoint get bp {
    final w = MediaQuery.sizeOf(this).width;
    if (w >= 1200) return Breakpoint.desktop;
    if (w >= 600)  return Breakpoint.tablet;
    return Breakpoint.mobile;
  }

  bool get isMobile  => bp == Breakpoint.mobile;
  bool get isTablet  => bp == Breakpoint.tablet;
  bool get isDesktop => bp == Breakpoint.desktop;
  bool get isWide    => bp != Breakpoint.mobile;

  /// Constrain content to a comfortable reading width on wide screens.
  double get contentMaxWidth => switch (bp) {
        Breakpoint.mobile  => double.infinity,
        Breakpoint.tablet  => 720,
        Breakpoint.desktop => 1100,
      };

  /// Grid columns for adaptive grids (lists, album).
  int columnsFor({int mobile = 1, int tablet = 2, int desktop = 3}) => switch (bp) {
        Breakpoint.mobile  => mobile,
        Breakpoint.tablet  => tablet,
        Breakpoint.desktop => desktop,
      };
}

/// Wraps content with a max-width on tablet/desktop so lists don't span absurd widths.
/// On mobile (where `contentMaxWidth` is infinite) we return the child unwrapped —
/// wrapping in `ConstrainedBox(maxWidth: infinity)` strips the parent's bounded
/// width and breaks any descendant relying on it (e.g. `Spacer`, button minSize).
class CenteredContent extends StatelessWidget {
  const CenteredContent({super.key, required this.child, this.maxWidth});
  final Widget child;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final mw = maxWidth ?? context.contentMaxWidth;
    if (!mw.isFinite) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: mw),
        child: child,
      ),
    );
  }
}
