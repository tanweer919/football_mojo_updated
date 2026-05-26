import 'package:flutter/material.dart';

/// Raw color tokens from `design-specs/css/tokens.css`. Source of truth.
///
/// Authored in oklch in the spec; converted to sRGB with matching perceptual
/// luminance/chroma. Values are stable — do not tweak per-screen.
class AppColors {
  AppColors._();

  // Surfaces
  static const bg          = Color(0xFF131211);
  static const bgDeep      = Color(0xFF0A0A09);
  static const surface     = Color(0xFF1B1A18);
  static const surface2    = Color(0xFF242220);
  static const surface3    = Color(0xFF2D2A27);
  static const surfaceHi   = Color(0xFF36322F);

  // Borders
  static const border      = Color(0xFF3F3B37);
  static const borderSoft  = Color(0xFF312E2B);
  static const borderHi    = Color(0xFF4D4844);

  // Text
  static const fg          = Color(0xFFF4F2EE);
  static const fgSoft      = Color(0xFFC9C5BC);
  static const muted       = Color(0xFF8E867B);
  static const muted2      = Color(0xFF5A5448);

  // Champagne gold accent system
  static const gold        = Color(0xFFE5C26B);
  static const goldDeep    = Color(0xFFC99A3D);
  static const goldSoft    = Color(0xFFEFD8A1);
  static const goldGlow    = Color(0x38E5C26B); // 22% alpha
  static const goldHairline= Color(0x73C99A3D); // 45% alpha

  // Status
  static const live        = Color(0xFFE94B33);
  static const liveGlow    = Color(0x47E94B33); // 28% alpha
  static const pitch       = Color(0xFF6FCD8B);
  static const pitchGlow   = Color(0x406FCD8B); // 25% alpha
  static const info        = Color(0xFF6BA6D0);
  static const warn        = Color(0xFFDEBF63);

  // Rarity
  static const rCommon     = Color(0xFF888B95);
  static const rRare       = Color(0xFF4FA0D6);
  static const rEpic       = Color(0xFFA268D5);
  static const rLegendary  = Color(0xFFDBB35E);
  static const rIconicA    = Color(0xFF4DBADC);
  static const rIconicB    = Color(0xFFD656B5);
  static const rIconicC    = Color(0xFFE1C26F);
}

/// Font family stacks. We don't bundle font files — the OS picks the closest
/// match from the family list, falling back to the system default.
class AppFonts {
  AppFonts._();

  static const display = 'InterDisplay';
  static const body    = 'Inter';
  static const mono    = 'JetBrainsMono';
  static const serif   = 'IowanOldStyle';

  static const displayFallback = ['Inter', 'SF Pro Display', 'Roboto', 'sans-serif'];
  static const bodyFallback    = ['SF Pro Text', 'Roboto', 'sans-serif'];
  static const monoFallback    = ['SF Mono', 'Menlo', 'Roboto Mono', 'monospace'];
  static const serifFallback   = ['Charter', 'Georgia', 'Times New Roman', 'serif'];
}
