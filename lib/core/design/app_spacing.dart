/// Spacing scale from `design-specs/css/tokens.css`.
class AppSpacing {
  AppSpacing._();
  static const double s1  = 4;
  static const double s2  = 8;
  static const double s3  = 12;
  static const double s4  = 16;
  static const double s5  = 20;
  static const double s6  = 24;
  static const double s7  = 32;
  static const double s8  = 40;
  static const double s9  = 48;
  static const double s10 = 64;
  static const double s11 = 80;

  // Backward-compat aliases so legacy screens keep compiling while they're
  // being ported to the new spec.
  static const double xs   = s1;
  static const double sm   = s2;
  static const double md   = s3;
  static const double lg   = s4;
  static const double xl   = s5;
  static const double xxl  = s6;
  static const double xxxl = s7;
  static const double huge = s9;
}

/// Radii from spec. Subtle, leather-tooled — no extreme rounding.
class AppRadii {
  AppRadii._();
  static const double r1 = 4;
  static const double r2 = 8;
  static const double r3 = 12;
  static const double r4 = 16;
  static const double r5 = 20;
  static const double full = 999;

  // Legacy aliases.
  static const double sm   = r2;
  static const double md   = r3;
  static const double lg   = r4;
  static const double xl   = r5;
  static const double xxl  = r5;
  static const double pill = full;
}
