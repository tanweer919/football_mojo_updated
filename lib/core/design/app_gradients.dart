import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Gradient tokens from `design-specs/css/tokens.css` + the per-screen
/// patterns established in `android/home.html` (wc-hero, fantasy-card,
/// featured-card backgrounds).
class AppGradients {
  AppGradients._();

  /// Default card surface.
  static const card = LinearGradient(
    colors: [AppColors.surface2, AppColors.surface],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Elevated card variant.
  static const cardHi = LinearGradient(
    colors: [AppColors.surface3, AppColors.surface2],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Champagne gold button — soft → mid → deep, matches `.btn--gold`.
  static const buttonGold = LinearGradient(
    colors: [AppColors.goldSoft, AppColors.gold, AppColors.goldDeep],
    stops: [0, 0.5, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// World Cup hero — dark with a green-pitch radial up top, matches the
  /// `.wc-hero` pattern.
  static const wcHero = LinearGradient(
    colors: [Color(0xFF231F1A), Color(0xFF14110F)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Pitch glow that overlays the wc-hero (use as separate radial layer).
  static const wcHeroGlow = RadialGradient(
    colors: [Color(0x736FCD8B), Colors.transparent],
    radius: 1.2,
    center: Alignment(0, -1.0),
    stops: [0.0, 0.55],
  );

  /// Fantasy card — gold radial top-right + dark base, matches `.fantasy-card`.
  static const fantasyCard = LinearGradient(
    colors: [Color(0xFF1F1A14), Color(0xFF14100C)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const fantasyCardGlow = RadialGradient(
    colors: [Color(0x40C99A3D), Colors.transparent],
    radius: 0.8,
    center: Alignment(1, -1),
    stops: [0.0, 0.6],
  );

  /// Featured card (epic mint) — purple-tinted, matches `.featured-card`.
  static const featuredCard = LinearGradient(
    colors: [Color(0xFF2A1740), Color(0xFF110820)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const featuredCardGlow = RadialGradient(
    colors: [Color(0x4DA268D5), Colors.transparent],
    radius: 0.8,
    center: Alignment(1, -1),
    stops: [0.0, 0.6],
  );

  /// Stage backdrop (used behind phone frame in the spec). For the live app
  /// the entire screen is `bgDeep` directly.
  static const stage = LinearGradient(
    colors: [AppColors.bgDeep, Color(0xFF050504)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Player headshot soft glow — used inside pcard above the photo.
  static const pcardHeadGlow = RadialGradient(
    colors: [Color(0x33FFFFFF), Colors.transparent],
    radius: 0.9,
    center: Alignment(0, -0.6),
  );

  /// Pcard bottom scrim — fades photo into the chrome.
  static const pcardScrim = LinearGradient(
    colors: [Colors.transparent, Colors.transparent, Color(0xB3000000)],
    stops: [0, 0.5, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Specular shine sweep across pcard.
  static const pcardShine = LinearGradient(
    colors: [Colors.transparent, Color(0x2EFFFFFF), Colors.transparent],
    stops: [0.30, 0.45, 0.60],
    begin: Alignment(-1, -0.5),
    end: Alignment(1, 0.5),
  );

  // ─── Legacy aliases (referenced by old screens being ported) ─────────────

  static LinearGradient hero(ColorScheme s) => wcHero;
  static LinearGradient liveHero(ColorScheme s) => const LinearGradient(
        colors: [Color(0xFF3A0E0E), Color(0xFF14110F)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
  static const aurora = featuredCard;
  static const turf = LinearGradient(
    colors: [Color(0xFF0A1F12), Color(0xFF050C07)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  static const floodlight = pcardHeadGlow;
  static const glass = LinearGradient(
    colors: [Color(0x33FFFFFF), Color(0x14FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
