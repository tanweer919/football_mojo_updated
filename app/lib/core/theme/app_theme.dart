import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/app_colors.dart';
import '../design/app_spacing.dart';

/// Pitch app theme — luxury dark + champagne gold.
///
/// Tokens come from `design-specs/css/tokens.css`. The app is dark-only by
/// design — no light variant defined in the spec.
class AppTheme {
  static ThemeData light(ColorScheme? _) => dark(null);

  static ThemeData dark(ColorScheme? _) {
    const scheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: AppColors.gold,
      onPrimary: Color(0xFF1E1810),
      primaryContainer: AppColors.goldDeep,
      onPrimaryContainer: Color(0xFF1E1810),
      secondary: AppColors.pitch,
      onSecondary: Color(0xFF0B1A0E),
      secondaryContainer: AppColors.surface3,
      onSecondaryContainer: AppColors.fg,
      tertiary: AppColors.info,
      onTertiary: Color(0xFF0B1620),
      error: AppColors.live,
      onError: Color(0xFF200807),
      errorContainer: Color(0xFF3A1812),
      onErrorContainer: Color(0xFFFFD9D2),
      surface: AppColors.bg,
      onSurface: AppColors.fg,
      surfaceContainerLowest: AppColors.bgDeep,
      surfaceContainerLow: AppColors.bg,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.surface2,
      surfaceContainerHighest: AppColors.surface3,
      onSurfaceVariant: AppColors.muted,
      outline: AppColors.border,
      outlineVariant: AppColors.borderSoft,
      inverseSurface: AppColors.fg,
      onInverseSurface: AppColors.bg,
      inversePrimary: AppColors.goldDeep,
      shadow: Colors.black,
      scrim: Colors.black,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      splashFactory: InkSparkle.splashFactory,
      fontFamily: 'Inter',
    );

    // Edge-to-edge: both bars are transparent, OS draws icons on top of our
    // gradient. With this + `SystemUiMode.edgeToEdge` (set in main.dart) the
    // black band that used to sit at the bottom of pushed screens is gone.
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ));

    final text = base.textTheme.apply(
      bodyColor: AppColors.fg,
      displayColor: AppColors.fg,
      fontFamily: 'Inter',
    ).copyWith(
      // Display 1 / 2 — Inter Display, 32 / 24, weight 800, very tight tracking.
      displayLarge:  const TextStyle(fontSize: 40, height: 1.05, fontWeight: FontWeight.w800, letterSpacing: -1.4),
      displayMedium: const TextStyle(fontSize: 32, height: 1.05, fontWeight: FontWeight.w800, letterSpacing: -1.12),
      displaySmall:  const TextStyle(fontSize: 24, height: 1.10, fontWeight: FontWeight.w800, letterSpacing: -0.72),

      // Headlines — Inter Display, 700-800, tight.
      headlineLarge: const TextStyle(fontSize: 22, height: 1.15, fontWeight: FontWeight.w800, letterSpacing: -0.44),
      headlineMedium:const TextStyle(fontSize: 20, height: 1.20, fontWeight: FontWeight.w700, letterSpacing: -0.40),
      headlineSmall: const TextStyle(fontSize: 18, height: 1.20, fontWeight: FontWeight.w700, letterSpacing: -0.36),

      titleLarge:    const TextStyle(fontSize: 17, height: 1.20, fontWeight: FontWeight.w700, letterSpacing: -0.26),
      titleMedium:   const TextStyle(fontSize: 15, height: 1.25, fontWeight: FontWeight.w700, letterSpacing: -0.22),
      titleSmall:    const TextStyle(fontSize: 14, height: 1.30, fontWeight: FontWeight.w600, letterSpacing: -0.14),

      // Body — Inter, 14, soft fg color.
      bodyLarge:     const TextStyle(fontSize: 15, height: 1.50, color: AppColors.fgSoft),
      bodyMedium:    const TextStyle(fontSize: 14, height: 1.50, color: AppColors.fgSoft),
      bodySmall:     const TextStyle(fontSize: 12, height: 1.45, color: AppColors.muted),

      // Labels — small, used for buttons + chips.
      labelLarge:    const TextStyle(fontSize: 14, height: 1.20, fontWeight: FontWeight.w600, letterSpacing: -0.07),
      labelMedium:   const TextStyle(fontSize: 12, height: 1.25, fontWeight: FontWeight.w600, letterSpacing: 0.0),
      labelSmall:    const TextStyle(fontSize: 11, height: 1.20, fontWeight: FontWeight.w600, letterSpacing: 0.0),
    );

    return base.copyWith(
      textTheme: text,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.fg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.fg,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          fontFamily: 'Inter',
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface2,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.r4)),
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: const Color(0xFF1E1810),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.r3)),
          minimumSize: const Size(88, 44),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: -0.07,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.fg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.r3)),
          minimumSize: const Size(88, 44),
          side: const BorderSide(color: AppColors.border, width: 1),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.gold,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.r2)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
        shape: const StadiumBorder(),
        backgroundColor: AppColors.surface2,
        labelStyle: const TextStyle(
          color: AppColors.fg,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface3,
        contentTextStyle: TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderSoft,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBackgroundColor: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.r5)),
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.border,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.bg,
        elevation: 0,
        height: 64,
      ),
    );
  }
}
