import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/assets.dart';
import '../../core/format.dart';
import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/food_photo.dart';
import '../../core/widgets/settings_widgets.dart';
import '../../state/providers.dart';

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premium = ref.watch(premiumProvider);
    final until = ref.watch(premiumUntilProvider);
    final scansLeft = ref.watch(freeScansProvider);
    final plans = ref.watch(proPlansProvider).value;
    final cheapest = plans == null || plans.isEmpty ? null : plans.last;

    return SettingsPage(
      title: 'Subscription',
      children: [
        ClipRRect(
          borderRadius: Radii.xlAll,
          child: Stack(
            children: [
              FoodPhoto(
                Photos.buddhaBowl,
                width: MediaQuery.sizeOf(context).width,
                height: 180,
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.75),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: Space.xl,
                right: Space.xl,
                bottom: Space.xl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Pill(
                      label: premium ? 'PRO · ACTIVE' : 'FREE PLAN',
                      background: premium
                          ? context.brand.accent
                          : Colors.white.withValues(alpha: 0.9),
                      foreground: context.brand.onAccent,
                    ),
                    const SizedBox(height: Space.sm),
                    Text(
                      premium ? 'NutriLens Pro' : 'NutriLens Free',
                      style: context.text.headlineSmall?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.photo_camera_outlined,
              title: 'AI photo scans',
              value: premium ? 'Unlimited' : '$scansLeft left',
            ),
            SettingsRow(
              icon: Icons.auto_awesome_outlined,
              title: 'Smart suggestions',
              value: premium ? 'Included' : 'Pro',
            ),
            SettingsRow(
              icon: Icons.insights_outlined,
              title: 'Weekly insights',
              value: premium ? 'Included' : 'Pro',
            ),
          ],
        ),
        const SizedBox(height: Space.xl),
        if (premium) ...[
          if (until != null)
            Text(
              'Pro is active until ${Fmt.dayMonth(until)} ${until.year}.',
              textAlign: TextAlign.center,
              style: context.text.titleSmall,
            ),
          const SizedBox(height: Space.md),
          FilledButton(
            onPressed: () => context.push(Routes.paywall),
            child: const Text('Extend Pro'),
          ),
          const SizedBox(height: Space.md),
          Text(
            'Pro is a one-time pass paid via Razorpay — nothing renews '
            'automatically. Buying again adds time to your current pass.',
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ] else ...[
          FilledButton(
            onPressed: () => context.push(Routes.paywall),
            child: const Text('Upgrade to Pro'),
          ),
          const SizedBox(height: Space.md),
          Text(
            '${cheapest == null ? 'One-time passes' : 'One-time passes from ${cheapest.priceLabel}'}'
            ' — no subscription. Pro is linked to your phone number, so it '
            'follows you to a new phone.',
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
