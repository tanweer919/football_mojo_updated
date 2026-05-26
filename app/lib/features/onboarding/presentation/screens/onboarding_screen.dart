import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_providers.dart';
import '../../../../core/auth/sign_in_sheet.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../../core/widgets/pitch_buttons.dart';
import '../../../../core/widgets/pitch_hero_stack.dart';

/// Onboarding — full-bleed welcome screen sharing the same visual vocabulary
/// as the sign-in sheet (3D card stack + grid background + CTA stack).
///
/// "Continue without account" lets the user skip — anonymous browsing is
/// supported across the app and the sign-in sheet pops just-in-time when an
/// auth-required action is tapped.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    void complete() {
      ref.read(onboardingCompleteProvider.notifier).markCompleted();
    }

    // One-tap: skip the intermediate showSignInSheet (which would require a
    // second "Continue with Google" tap inside the sheet) and trigger the
    // Google chooser directly. quickSignIn also runs the welcome-card peek
    // on success — without this, first-time signups never saw the reveal
    // because showSignInSheet doesn't call _maybeShowWelcomeCard itself.
    Future<void> signInThenComplete() async {
      final user = await quickSignIn(context, ref);
      if (user != null) complete();
    }

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: PitchGridBackground(
        child: Stack(
          children: [
            // Brand mark, centred at the top.
            Positioned(
              top: topInset + 16, left: 0, right: 0,
              child: const _Brand(),
            ),

            // 3D card stage.
            Positioned(
              top: topInset + 64, left: 0, right: 0,
              child: const PitchHeroStack(height: 360, cardWidth: 180),
            ),

            // Bottom block.
            Positioned(
              left: 16, right: 16, bottom: bottomInset > 0 ? bottomInset : 16,
              child: _BottomBlock(
                onSignIn: signInThenComplete,
                onSkip: complete,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();
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
  const _BottomBlock({required this.onSignIn, required this.onSkip});
  final VoidCallback onSignIn;
  final VoidCallback onSkip;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Eyebrow('Welcome to PITCH', gold: true, size: 11),
        const SizedBox(height: 14),
        RichText(
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
        const SizedBox(height: 14),
        const _Bullets(),
        const SizedBox(height: 18),
        const _Dots(count: 3, active: 0),
        const SizedBox(height: 18),
        GoldButton(
          label: 'Sign in to PITCH',
          onPressed: onSignIn,
          expand: true,
        ),
        const SizedBox(height: 8),
        GhostButton(
          label: 'Continue without account',
          onPressed: onSkip,
          expand: true,
        ),
        const SizedBox(height: 12),
        const _Legal(),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Bullet('Live scores, news & World Cup 2026 in one home'),
          _Bullet('Global Cup, 1v1 ladders, friend leagues'),
          _Bullet('Earn iconic player cards — yours forever'),
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

class _Legal extends StatelessWidget {
  const _Legal();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
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
    );
  }
}
