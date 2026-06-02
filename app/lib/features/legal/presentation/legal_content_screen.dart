import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/widgets/eyebrow.dart';
import '../../../core/widgets/pitch_scaffold.dart';

/// Static legal / help-text screen.
///
/// Single screen used for Privacy Policy, Terms of Service, and the
/// Help Centre. Renders a list of sections (heading + body paragraphs)
/// so we can update the copy without redesigning each page. All three
/// pages share the same scaffold styling.
class LegalContentScreen extends StatelessWidget {
  const LegalContentScreen({
    super.key,
    required this.title,
    required this.lastUpdated,
    required this.intro,
    required this.sections,
  });

  final String title;
  /// Plain-text date string shown under the title, e.g. "Updated June 2026".
  final String lastUpdated;
  final String intro;
  final List<LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    return PitchScreen(
      title: title,
      onBack: () => context.canPop() ? context.pop() : context.go('/profile'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Eyebrow(lastUpdated, gold: true, size: 10),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: AppColors.fg,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              intro,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: AppColors.muted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            for (final s in sections) _SectionBlock(section: s),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(AppRadii.r3),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Row(
                children: const [
                  Icon(Icons.email_outlined, color: AppColors.gold, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Questions? Reach us at support@footballmojo.in',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        color: AppColors.fg,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LegalSection {
  const LegalSection({required this.heading, required this.body});
  final String heading;
  final String body;
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({required this.section});
  final LegalSection section;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.heading,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: AppColors.gold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            section.body,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.5,
              color: AppColors.fg,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Concrete screens ──────────────────────────────────────────────────────

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const LegalContentScreen(
      title: 'Privacy policy',
      lastUpdated: 'Updated June 2026',
      intro:
          'FootballMojo respects your privacy. This page explains what we collect, '
          'why we collect it, and how we use it. We keep the list short because '
          'we don’t collect anything we don’t need.',
      sections: [
        LegalSection(
          heading: 'What we collect',
          body:
              'Your Google account info (name, email, profile photo) when you sign in; '
              'app activity inside FootballMojo (matches viewed, predictions made, '
              'cards owned); and crash reports + anonymous analytics events. We do '
              'not access your contacts, photos, microphone, or location.',
        ),
        LegalSection(
          heading: 'How we use it',
          body:
              'To run your account, save your fantasy lineup and bracket, sync your '
              'card collection across devices, surface stories about teams you '
              'follow, and send you the notifications you’ve opted in to. Analytics '
              'data is only used to improve the app — it’s never sold.',
        ),
        LegalSection(
          heading: 'Who we share with',
          body:
              'Firebase (Google) for authentication and crash logging, our hosting '
              'provider for serving the app, and api-football.com for fixture and '
              'live-score data. Each of these acts as a processor — they handle '
              'data on our behalf and don’t reuse it.',
        ),
        LegalSection(
          heading: 'Your rights',
          body:
              'You can sign out at any time from the profile screen. To delete your '
              'account and all associated data, email support@footballmojo.in from '
              'the address linked to your account — we process deletions within 30 '
              'days. You also have the right to request a copy of the data we hold '
              'about you.',
        ),
        LegalSection(
          heading: 'Children',
          body:
              'FootballMojo is not directed at children under 13. We do not knowingly '
              'collect data from anyone under 13. If you believe we have, contact us '
              'and we’ll delete it.',
        ),
        LegalSection(
          heading: 'Changes',
          body:
              'We may update this policy as the app evolves. Material changes will '
              'be announced inside the app. Continuing to use FootballMojo after a '
              'change means you accept the updated policy.',
        ),
      ],
    );
  }
}

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const LegalContentScreen(
      title: 'Terms of service',
      lastUpdated: 'Updated June 2026',
      intro:
          'By using FootballMojo, you agree to the terms below. They’re short on '
          'purpose — we want them to be readable, not a legal trap.',
      sections: [
        LegalSection(
          heading: 'Using FootballMojo',
          body:
              'You need a Google account to sign in. You’re responsible for the '
              'activity that happens on your account. Keep it to one human per '
              'account — no bots, no scrapers, no automated farming of gems or '
              'cards.',
        ),
        LegalSection(
          heading: 'Predictions and rewards',
          body:
              'FootballMojo is a prediction game, not a betting platform. We never '
              'take real-money wagers. Gems, cards, and leaderboard placement are '
              'virtual rewards and have no cash value. Bracket lock times and '
              'scoring rules are final once published for a tournament.',
        ),
        LegalSection(
          heading: 'Content and data',
          body:
              'Fixture, lineup, and live-score data comes from third-party '
              'providers and is offered as-is. Outcomes are determined by the '
              'official competition organisers — if our data is wrong, we’ll '
              'correct it but we’re not the source of truth.',
        ),
        LegalSection(
          heading: 'In-app purchases',
          body:
              'Purchases of gems or other virtual items are processed by the App '
              'Store or Google Play. Refunds follow their refund policies, not '
              'ours. Virtual items are non-transferable and tied to your '
              'FootballMojo account.',
        ),
        LegalSection(
          heading: 'Termination',
          body:
              'We may suspend or close an account that breaks these rules, abuses '
              'other users, or attempts to manipulate scoring. You can close your '
              'account at any time by emailing support.',
        ),
        LegalSection(
          heading: 'Liability',
          body:
              'FootballMojo is provided as-is. We do our best to keep the app '
              'reliable but don’t guarantee uninterrupted service. We’re not '
              'liable for indirect or consequential losses arising from your use '
              'of the app.',
        ),
      ],
    );
  }
}

class HelpCentreScreen extends StatelessWidget {
  const HelpCentreScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const LegalContentScreen(
      title: 'Help centre',
      lastUpdated: 'Updated June 2026',
      intro:
          'Quick answers to the questions we hear most. Can’t find what you’re '
          'looking for? Email us at support@footballmojo.in and we’ll get back '
          'within one business day.',
      sections: [
        LegalSection(
          heading: 'How does the World Cup bracket work?',
          body:
              'Open the bracket from home or the World Cup tab. Order each '
              'group’s teams 1st-to-4th by dragging, pick which 8 of the 12 '
              'third-placed teams advance, then choose a winner for every '
              'knockout match through to the final. Picks lock when the '
              'tournament’s first game kicks off. You earn gems and points as '
              'real results come in.',
        ),
        LegalSection(
          heading: 'How do I follow a team?',
          body:
              'Tap "Pick teams" on the home screen, or open any team page and '
              'tap the heart icon. Followed teams get their own news tab, their '
              'fixtures float to the top of the Matches strip, and you can opt '
              'in to live goal alerts per team in Notification preferences.',
        ),
        LegalSection(
          heading: 'What are gems for?',
          body:
              'Gems are FootballMojo’s in-app currency. You earn them by '
              'finishing well in fantasy gameweeks, scoring on your bracket, '
              'winning H2H matches, and completing card-set milestones. You '
              'spend them on packs in the Market.',
        ),
        LegalSection(
          heading: 'My live scores aren’t updating',
          body:
              'Pull to refresh on the matches page. If a game is in progress '
              'and the score is stuck, it usually means our data provider hasn’t '
              'pushed yet — give it a minute. If a match has been over for an '
              'hour and still shows live, email support with the match ID.',
        ),
        LegalSection(
          heading: 'How do I sign out or delete my account?',
          body:
              'Sign out from the bottom of the profile screen. To delete your '
              'account, email support@footballmojo.in from the address on the '
              'account — we’ll process the deletion within 30 days.',
        ),
        LegalSection(
          heading: 'Reporting a bug',
          body:
              'Tap your avatar → Help centre → contact email at the bottom, '
              'and include what you were doing, what you expected, and what '
              'happened. A screenshot helps. We read every email.',
        ),
      ],
    );
  }
}
