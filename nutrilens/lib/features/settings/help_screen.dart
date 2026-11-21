import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/settings_widgets.dart';

/// Replace with your real support inbox before launch.
const supportEmail = 'support@nutrilens.app';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faq = [
    (
      'How accurate are photo scans?',
      'For common dishes the AI is usually within 10–20% of lab values. '
          'Portion size is the biggest variable, so tap any item to adjust it '
          'before logging. Packaged food is most accurate via barcode.',
    ),
    (
      'How do I get the best results?',
      'Shoot from above in good light, fit the whole plate in the frame and '
          'avoid heavy filters. Separate items scan better than mixed bowls.',
    ),
    (
      'Can I log food without a photo?',
      'Yes — use barcode scan for packaged food, or search and type '
          'something like “2 rotis and dal”.',
    ),
    (
      'How are my calorie targets calculated?',
      'We use the Mifflin–St Jeor equation with your age, sex, height, '
          'weight and activity, then adjust for your goal and weekly pace. '
          'You can set custom targets in Daily targets.',
    ),
    (
      'I didn’t receive the SMS code',
      'Check the country code and number, wait 30 seconds and tap '
          '“Resend code”. Some carriers delay messages to international '
          'numbers by a minute or two.',
    ),
    (
      'Will I be charged automatically?',
      'No. Pro is a one-time pass (1 week, 1 month or 1 year) paid through '
          'Razorpay with UPI, cards, net banking or wallets. Nothing renews — '
          'buy again whenever you like to add more time.',
    ),
    (
      'I paid but Pro isn\'t active',
      'Payments are confirmed within a minute, even if the app closed during '
          'payment. Pull to refresh or reopen the app. Still stuck? Email us '
          'with your Razorpay payment ID (starts with pay_) and we\'ll fix it.',
    ),
    (
      'Is my data private?',
      'Your meals and body data are used only to run the app. We never sell '
          'your data. You can delete your account and all data at any time '
          'from Account & data.',
    ),
  ];

  Future<void> _contact(BuildContext context) async {
    final ok = await launchUrl(
      Uri(
        scheme: 'mailto',
        path: supportEmail,
        queryParameters: {'subject': 'NutriLens support'},
      ),
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email us at $supportEmail')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPage(
      title: 'Help & FAQ',
      children: [
        AppCard(
          padding: const EdgeInsets.all(Space.lg),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: context.brand.accent,
                  borderRadius: Radii.mdAll,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(Space.sm),
                  child: Icon(
                    Icons.support_agent_rounded,
                    color: context.brand.onAccent,
                  ),
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Need a hand?', style: context.text.titleSmall),
                    Text(
                      'We usually reply within a day.',
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () => _contact(context),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                child: const Text('Email us'),
              ),
            ],
          ),
        ),
        const GroupLabel('Frequently asked'),
        DecoratedBox(
          decoration: BoxDecoration(
            color: context.brand.card,
            borderRadius: Radii.xlAll,
            border: Border.all(color: context.colors.outlineVariant),
          ),
          child: ClipRRect(
            borderRadius: Radii.xlAll,
            child: Column(
              children: [
                for (var i = 0; i < _faq.length; i++) ...[
                  if (i > 0) const Divider(),
                  Theme(
                    data: context.theme.copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      title: Text(_faq[i].$1, style: context.text.titleSmall),
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: Space.lg,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(
                        Space.lg,
                        0,
                        Space.lg,
                        Space.lg,
                      ),
                      expandedAlignment: Alignment.centerLeft,
                      children: [
                        Text(
                          _faq[i].$2,
                          style: context.text.bodyMedium?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
