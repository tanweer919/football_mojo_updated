import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/data/profile_repository.dart';
import '../../features/welcome/presentation/screens/welcome_card_reveal_screen.dart';
import '../design/app_colors.dart';
import '../widgets/eyebrow.dart';
import '../widgets/pitch_buttons.dart';
import '../widgets/pitch_hero_stack.dart';
import 'auth_repository.dart';

/// Full-screen Welcome / Sign-in surface — Google-only on Android per the
/// product brief.
///
/// Visual matches `design-specs/android/onboarding.html`:
///   - radial-washed dark background with hairline 24px grid
///   - brand mark top-centre
///   - 3D card stack (Mbappé · Yamal · Bellingham)
///   - eyebrow + headline + 3 bullets + 3 dots
///   - CTA stack: "Continue with email" gold, then Google ghost button
///   - legal disclaimer
///
/// Returns the signed-in [User] on success, `null` on dismiss.
Future<User?> showSignInSheet(
  BuildContext context, {
  String? reason,
}) {
  return Navigator.of(context, rootNavigator: true).push<User?>(
    PageRouteBuilder(
      opaque: true,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, anim, __) => _SignInScreen(reason: reason),
      transitionsBuilder: (_, anim, __, child) {
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.04), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeOutCubic))
                .animate(anim),
            child: child,
          ),
        );
      },
    ),
  );
}

/// Convenience: returns the existing user if already signed in (and not
/// anonymous), otherwise opens the sign-in screen and returns the result.
Future<User?> ensureSignedIn(
  BuildContext context,
  WidgetRef ref, {
  String? reason,
}) async {
  final existing = ref.read(authRepositoryProvider).currentUser;
  if (existing != null && !existing.isAnonymous) return existing;
  if (!_isSignInSupported()) return null;
  final user = await showSignInSheet(context, reason: reason);
  if (user != null && context.mounted) {
    await _maybeShowWelcomeCard(context, ref);
  }
  return user;
}

/// After a successful sign-in, peek at /me. If the server has a freshly
/// minted welcome card sitting in `welcomeCard`, push the reveal screen.
/// Silent no-op when there's no card or the profile fetch fails.
///
/// Called automatically from `ensureSignedIn` and `quickSignIn` so every
/// auth-required CTA in the app pops the reveal exactly once on first
/// signup. Subsequent sign-ins find `welcomeCard == null` (server cleared
/// the flag on dismiss) and skip silently.
Future<void> _maybeShowWelcomeCard(BuildContext context, WidgetRef ref) async {
  try {
    // Force a fresh fetch — the cached profile pre-signin had no auth header.
    ref.invalidate(myProfileProvider);
    final profile = await ref.read(myProfileProvider.future);
    final card = profile?.welcomeCard;
    if (card == null || !context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 360),
        pageBuilder: (_, __, ___) => WelcomeCardRevealScreen(card: card),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  } catch (_) {
    // Non-fatal — sign-in already succeeded. Reveal will fire on the next
    // /me read (typically when the user opens their profile).
  }
}

/// **One-tap sign-in** for in-app CTAs (e.g. "Sign in to claim", "Save
/// lineup"). Skips the full Welcome screen and triggers the Google flow
/// directly — the user already understands the context.
///
/// Shows a translucent loading overlay while Google's chooser opens, surfaces
/// failures via SnackBar, and returns the signed-in user (or null on cancel).
///
/// Reserve [showSignInSheet] for the *first-time* onboarding flow where the
/// branded welcome screen earns its keep.
Future<User?> quickSignIn(BuildContext context, WidgetRef ref) async {
  final existing = ref.read(authRepositoryProvider).currentUser;
  if (existing != null && !existing.isAnonymous) return existing;
  if (!_isSignInSupported()) return null;

  // Capture context-bound objects before awaiting to keep the linter happy
  // and survive widget rebuilds.
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  // Translucent dim while we wait for Google's chooser.
  final overlay = OverlayEntry(builder: (_) => const _SignInOverlay());
  navigator.overlay?.insert(overlay);

  try {
    final user = await ref.read(authRepositoryProvider).signInWithGoogle();
    overlay.remove();
    if (context.mounted) await _maybeShowWelcomeCard(context, ref);
    return user;
  } on FirebaseAuthException catch (e) {
    overlay.remove();
    if (e.code == 'cancelled') return null;
    messenger.showSnackBar(
      SnackBar(content: Text(e.message ?? 'Sign-in failed.')),
    );
    return null;
  } catch (e) {
    overlay.remove();
    messenger.showSnackBar(SnackBar(content: Text('$e')));
    return null;
  }
}

class _SignInOverlay extends StatelessWidget {
  const _SignInOverlay();
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: Colors.black.withValues(alpha: 0.55))),
        const Center(
          child: SizedBox(
            width: 44, height: 44,
            child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 3),
          ),
        ),
      ],
    );
  }
}

bool _isSignInSupported() {
  if (kIsWeb) return false;
  try {
    return Platform.isAndroid || Platform.isIOS;
  } catch (_) {
    return false;
  }
}

class _SignInScreen extends ConsumerStatefulWidget {
  const _SignInScreen({this.reason});
  final String? reason;
  @override
  ConsumerState<_SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<_SignInScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await ref.read(authRepositoryProvider).signInWithGoogle();
      if (!mounted) return;
      Navigator.of(context).pop(user);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'cancelled') {
        setState(() => _busy = false);
        return;
      }
      setState(() {
        _busy = false;
        _error = e.message ?? 'Sign-in failed.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: PitchGridBackground(
        child: SafeArea(
          minimum: const EdgeInsets.symmetric(horizontal: 16),
          child: Stack(
            children: [
              // Close affordance — top-left so the user always has an out.
              Positioned(
                top: 0, left: 0,
                child: CircleIconButton(
                  icon: Icons.close,
                  onPressed: () => Navigator.of(context).pop(null),
                ),
              ),

              // Brand mark, anchored top-centre.
              Positioned(
                top: 6, left: 0, right: 0,
                child: const _BrandMark(),
              ),

              // 3D card stage — fills the upper half.
              Positioned(
                top: 64, left: 0, right: 0,
                child: const PitchHeroStack(height: 360, cardWidth: 180),
              ),

              // Bottom block — copy + dots + CTAs.
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: _BottomBlock(
                  reason: widget.reason,
                  busy: _busy,
                  error: _error,
                  onGoogle: _signIn,
                  bottomSafe: bottomInset,
                ),
              ),

              // Reserve top-inset only — the close button is above SafeArea.
              SizedBox(height: topInset),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22, height: 22,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0xFFF1E4B6), Color(0xFFE5C26B), Color(0xFF8E6422)],
                stops: [0.2, 0.6, 1.0],
                center: Alignment(-0.3, -0.4),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              colors: [AppColors.goldSoft, AppColors.goldDeep],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ).createShader(rect),
            child: const Text(
              'PITCH',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.32,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBlock extends StatelessWidget {
  const _BottomBlock({
    required this.reason,
    required this.busy,
    required this.error,
    required this.onGoogle,
    required this.bottomSafe,
  });
  final String? reason;
  final bool busy;
  final String? error;
  final VoidCallback onGoogle;
  final double bottomSafe;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 0, 0, bottomSafe > 0 ? bottomSafe : 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Eyebrow + headline ───────────────────────────────────────
          const Eyebrow('Welcome to PITCH', gold: true, size: 11),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.44,
                  color: AppColors.fg,
                  height: 1.0,
                ),
                children: [
                  TextSpan(text: 'Where football\nis '),
                  TextSpan(
                    text: 'played,',
                    style: TextStyle(
                      fontFamily: 'IowanOldStyle',
                      fontFamilyFallback: ['Charter', 'Georgia', 'serif'],
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                      color: AppColors.gold,
                    ),
                  ),
                  TextSpan(text: ' not\njust watched.'),
                ],
              ),
            ),
          ),

          // Reason / error contextual line.
          if (reason != null || error != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                error ?? reason!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: error != null ? AppColors.live : AppColors.muted,
                  height: 1.45,
                ),
              ),
            ),
          ],

          // ── Bullets (compact — 3 lines, gold dots) ───────────────────
          const SizedBox(height: 14),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Bullet('Live scores, news & World Cup 2026 in one home'),
                _Bullet('Global Cup, 1v1 ladders, friend leagues'),
                _Bullet('Earn iconic player cards — yours forever'),
              ],
            ),
          ),

          // ── Progress dots ────────────────────────────────────────────
          const SizedBox(height: 18),
          const _Dots(count: 3, active: 0),

          // ── CTAs ─────────────────────────────────────────────────────
          const SizedBox(height: 18),
          if (busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: CircularProgressIndicator(color: AppColors.gold),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GoldButton(
                label: 'Continue with Google',
                icon: Icons.g_mobiledata,
                onPressed: onGoogle,
                expand: true,
              ),
            ),

          // ── Legal ────────────────────────────────────────────────────
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                  fontSize: 9,
                  color: AppColors.muted2,
                  letterSpacing: 0.54,
                  height: 1.5,
                ),
                children: [
                  TextSpan(text: 'By continuing you agree to PITCH’s '),
                  TextSpan(text: 'Terms', style: TextStyle(color: AppColors.gold)),
                  TextSpan(text: ' and '),
                  TextSpan(text: 'Privacy', style: TextStyle(color: AppColors.gold)),
                  TextSpan(text: '.\nNo gambling. Cards are collectibles only.'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 5, height: 5,
            decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                color: AppColors.fgSoft,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});
  final int count;
  final int active;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 32 : 22,
          height: 4,
          decoration: BoxDecoration(
            color: isActive ? AppColors.gold : const Color(0xFF2A2622),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

