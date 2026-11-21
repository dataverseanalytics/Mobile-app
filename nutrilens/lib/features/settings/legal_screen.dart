import 'package:flutter/material.dart';

import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/settings_widgets.dart';
import 'help_screen.dart';

enum LegalDoc { terms, privacy }

/// Terms of Use and Privacy Policy.
///
/// This is a starting template written for an app of this kind. Have it
/// reviewed by a lawyer for each market you launch in (e.g. GDPR in the EU,
/// DPDP Act in India, CCPA in California) before publishing.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.doc});
  final LegalDoc doc;

  static const _updated = '20 November 2026';

  static const _terms = [
    (
      'Using NutriLens',
      'NutriLens helps you estimate the nutrition of the food you eat. You '
          'must be at least 16 years old, or the age of digital consent in '
          'your country, to create an account.',
    ),
    (
      'Not medical advice',
      'Calorie and nutrient estimates are approximate and for general '
          'wellness only. NutriLens is not a medical device and does not '
          'diagnose or treat any condition. Talk to a qualified professional '
          'before making major changes to your diet, especially if you are '
          'pregnant, have diabetes or have a history of eating disorders.',
    ),
    (
      'Your account',
      'You sign in with your mobile number and a one-time code. Keep access '
          'to your phone secure; you are responsible for activity on your '
          'account.',
    ),
    (
      'Payments',
      'NutriLens Pro is sold as one-time passes (1 week, 1 month or 1 year), '
          'paid securely through Razorpay. Prices include applicable taxes. '
          'Passes do not renew automatically; buying again extends your '
          'current pass. If something goes wrong with a payment, contact us '
          'within 7 days for a review and, where appropriate, a refund to '
          'the original payment method.',
    ),
    (
      'Acceptable use',
      'Don’t misuse the service, attempt to access it in unauthorised ways, '
          'or upload content you don’t have the right to share.',
    ),
    (
      'Changes and termination',
      'We may update these terms and will notify you of material changes in '
          'the app. You can stop using NutriLens and delete your account at '
          'any time.',
    ),
  ];

  static const _privacy = [
    (
      'What we collect',
      'Your phone number (to sign you in), the name and optional email you '
          'provide, body details you enter during setup (age, height, weight, '
          'activity, goal), meal photos you scan and the meals you log.',
    ),
    (
      'How we use it',
      'Only to provide NutriLens: analysing meal photos, calculating your '
          'targets, showing your progress and sending reminders you turn on. '
          'We do not sell your personal data or use your photos for '
          'advertising.',
    ),
    (
      'Meal photos',
      'Photos are sent securely to our servers for analysis and are not '
          'shared publicly. You choose what to share using the share card.',
    ),
    (
      'Service providers',
      'We use trusted providers to run the app — an SMS provider to send '
          'sign-in codes, an AI vision provider for photo analysis, and '
          'Razorpay for payments (we never see or store your card or UPI '
          'details). They process data on our behalf '
          'under contract.',
    ),
    (
      'Your rights',
      'You can view and edit your data in the app, export it on request, and '
          'delete your account and all associated data at any time from '
          'Profile → Account & data.',
    ),
    ('Contact', 'Questions about privacy? Email $supportEmail.'),
  ];

  @override
  Widget build(BuildContext context) {
    final sections = doc == LegalDoc.terms ? _terms : _privacy;
    return SettingsPage(
      title: doc == LegalDoc.terms ? 'Terms of Use' : 'Privacy Policy',
      children: [
        Text(
          'Last updated $_updated',
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        for (final (title, body) in sections) ...[
          const SizedBox(height: Space.xxl),
          Semantics(
            header: true,
            child: Text(title, style: context.text.titleMedium),
          ),
          const SizedBox(height: Space.sm),
          Text(body, style: context.text.bodyMedium?.copyWith(height: 1.6)),
        ],
      ],
    );
  }
}
