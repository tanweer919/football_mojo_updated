import 'package:flutter/animation.dart';

/// Motion tokens from `design-specs/css/tokens.css`.
///   --ease:        cubic-bezier(.2, .7, .2, 1)
///   --ease-spring: cubic-bezier(.34, 1.56, .64, 1)
class AppMotion {
  AppMotion._();

  // Durations — short and crisp for luxury feel.
  static const xs = Duration(milliseconds: 120);
  static const sm = Duration(milliseconds: 200);
  static const md = Duration(milliseconds: 320);
  static const lg = Duration(milliseconds: 480);
  static const xl = Duration(milliseconds: 720);

  // Curves — match the spec's two custom cubic-beziers exactly.
  static const ease       = Cubic(0.2,  0.7,  0.2,  1.0);
  static const easeSpring = Cubic(0.34, 1.56, 0.64, 1.0);

  // Convenient aliases used throughout the app.
  static const enter = ease;
  static const swap  = ease;
  static const pop   = easeSpring;
  static const exit  = ease;
}
