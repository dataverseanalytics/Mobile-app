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
import '../auth/phone_utils.dart';
import '../onboarding/onboarding_widgets.dart';
import '../settings/about_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    final profile = ref.watch(profileProvider);
    final targets = ref.watch(targetsProvider);
    final custom = ref.watch(customTargetsProvider) != null;
    final premium = ref.watch(premiumProvider);
    final mode = ref.watch(themeModeProvider);
    final remindersOn = ref
        .watch(remindersProvider)
        .where((r) => r.enabled)
        .length;
    final unread = ref.watch(unreadNoticesProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('Profile')),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              Space.gutter,
              0,
              Space.gutter,
              MediaQuery.paddingOf(context).bottom + Space.xxxl,
            ),
            sliver: SliverList.list(
              children: [
                Material(
                  color: context.brand.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: Radii.xlAll,
                    side: BorderSide(color: context.colors.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => context.push(Routes.editProfile),
                    child: Padding(
                      padding: const EdgeInsets.all(Space.lg),
                      child: Row(
                        children: [
                          _Avatar(initials: account?.initials ?? ''),
                          const SizedBox(width: Space.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  account?.name.isNotEmpty == true
                                      ? account!.name
                                      : 'Your profile',
                                  style: context.text.titleLarge,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: Space.xxs),
                                Text(
                                  account == null
                                      ? ''
                                      : PhoneUtils.pretty(account.phone),
                                  style: context.text.bodySmall?.copyWith(
                                    color: context.colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: context.colors.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Space.md),
                if (premium)
                  AppCard(
                    color: context.brand.accent,
                    padding: const EdgeInsets.all(Space.lg),
                    child: Row(
                      children: [
                        Icon(
                          Icons.workspace_premium_rounded,
                          color: context.brand.onAccent,
                        ),
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: Text(
                            'NutriLens Pro is active',
                            style: context.text.titleMedium?.copyWith(
                              color: context.brand.onAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  _ProCard(onTap: () => context.push(Routes.paywall)),
                const GroupLabel('My plan'),
                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: Icons.flag_outlined,
                      title: profile.goal.label,
                      subtitle:
                          '${profile.weightKg.toStringAsFixed(1)} kg → '
                          '${profile.targetWeightKg.toStringAsFixed(1)} kg · '
                          '${profile.activity.label}',
                      onTap: () => context.push(Routes.onboarding),
                    ),
                    SettingsRow(
                      icon: Icons.local_fire_department_outlined,
                      title: 'Daily targets',
                      subtitle: custom ? 'Custom' : 'Automatic',
                      value: '${Fmt.kcal(targets.kcal)} kcal',
                      onTap: () => context.push(Routes.goals),
                    ),
                  ],
                ),
                const GroupLabel('Preferences'),
                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notifications',
                      value: unread > 0 ? '$unread new' : null,
                      onTap: () => context.push(Routes.notifications),
                    ),
                    SettingsRow(
                      icon: Icons.alarm_rounded,
                      title: 'Reminders',
                      value: remindersOn == 0 ? 'Off' : '$remindersOn on',
                      onTap: () => context.push(Routes.reminders),
                    ),
                    SettingsRow(
                      icon: Icons.workspace_premium_outlined,
                      title: 'Subscription',
                      value: premium ? 'Pro' : 'Free',
                      onTap: () => context.push(Routes.subscription),
                    ),
                  ],
                ),
                const GroupLabel('Appearance'),
                Segmented<ThemeMode>(
                  options: ThemeMode.values,
                  value: mode,
                  labelOf: (m) => switch (m) {
                    ThemeMode.system => 'System',
                    ThemeMode.light => 'Light',
                    ThemeMode.dark => 'Dark',
                  },
                  onChanged: (m) => ref.read(themeModeProvider.notifier).set(m),
                ),
                const GroupLabel('Support'),
                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: Icons.help_outline_rounded,
                      title: 'Help & FAQ',
                      onTap: () => context.push(Routes.help),
                    ),
                    SettingsRow(
                      icon: Icons.lock_outline_rounded,
                      title: 'Privacy Policy',
                      onTap: () => context.push(Routes.privacy),
                    ),
                    SettingsRow(
                      icon: Icons.description_outlined,
                      title: 'Terms of Use',
                      onTap: () => context.push(Routes.terms),
                    ),
                    SettingsRow(
                      icon: Icons.info_outline_rounded,
                      title: 'About NutriLens',
                      onTap: () => context.push(Routes.about),
                    ),
                  ],
                ),
                const GroupLabel('Account'),
                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: Icons.manage_accounts_outlined,
                      title: 'Account & data',
                      subtitle: 'Sign out or delete your account',
                      onTap: () => context.push(Routes.account),
                    ),
                  ],
                ),
                const SizedBox(height: Space.xxl),
                Center(
                  child: Text(
                    'NutriLens $appVersion',
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials});
  final String initials;
  static const size = 56.0;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.brand.accent,
          shape: BoxShape.circle,
        ),
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: initials.isEmpty
                ? Icon(Icons.person_rounded, color: context.brand.onAccent)
                : Text(
                    initials,
                    style: context.text.titleLarge?.copyWith(
                      color: context.brand.onAccent,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ProCard extends StatelessWidget {
  const _ProCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF14140F),
      borderRadius: Radii.xlAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(Space.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Pill(
                      label: 'PRO',
                      background: context.brand.accent,
                      foreground: context.brand.onAccent,
                    ),
                    const SizedBox(height: Space.md),
                    Text(
                      'Unlimited scans & smart suggestions',
                      style: context.text.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      'Try free for 3 days',
                      style: context.text.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const FoodPhoto(Photos.berryYogurtBowl, width: 112, height: 150),
          ],
        ),
      ),
    );
  }
}
