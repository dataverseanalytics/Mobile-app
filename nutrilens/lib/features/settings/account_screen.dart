import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/format.dart';
import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/settings_widgets.dart';
import '../../state/providers.dart';
import '../auth/phone_utils.dart';

/// Sign-in details, sign out and permanent account deletion.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _busy = false;

  Future<void> _signOut() async {
    final ok = await confirmAction(
      context,
      title: 'Sign out?',
      message:
          'Your meals stay saved to your account on this device until '
          'someone else signs in.',
      confirmLabel: 'Sign out',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final router = GoRouter.of(context);
    await ref.read(accountProvider.notifier).signOut();
    router.go(Routes.welcome);
  }

  Future<void> _delete() async {
    final ok = await confirmAction(
      context,
      title: 'Delete your account?',
      message:
          'This permanently deletes your profile, meals, photos and progress. '
          'Active subscriptions must be cancelled separately in your store '
          'account. This can’t be undone.',
      confirmLabel: 'Delete account',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(accountProvider.notifier).deleteAccount();
      router.go(Routes.welcome);
      messenger.showSnackBar(
        const SnackBar(content: Text('Your account has been deleted.')),
      );
    } on Object {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't delete your account. Please try again."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountProvider);
    final meals = ref.watch(diaryProvider).length;
    final isDemo = ref.watch(authRepositoryProvider).isDemo;

    return SettingsPage(
      title: 'Account & data',
      children: [
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.phone_iphone_rounded,
              title: 'Phone',
              value: account == null ? '—' : PhoneUtils.pretty(account.phone),
            ),
            SettingsRow(
              icon: Icons.verified_user_outlined,
              title: 'Sign-in method',
              value: isDemo ? 'SMS code (demo)' : 'SMS code',
            ),
            SettingsRow(
              icon: Icons.calendar_today_outlined,
              title: 'Member since',
              value: account == null
                  ? '—'
                  : '${Fmt.dayMonth(account.createdAt)} ${account.createdAt.year}',
            ),
            SettingsRow(
              icon: Icons.restaurant_menu_rounded,
              title: 'Meals logged',
              value: '$meals',
            ),
          ],
        ),
        const SizedBox(height: Space.xxl),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.logout_rounded,
              title: 'Sign out',
              onTap: _busy ? null : _signOut,
            ),
          ],
        ),
        const SizedBox(height: Space.md),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.delete_forever_outlined,
              title: 'Delete account',
              subtitle: 'Permanently remove your account and all data',
              destructive: true,
              onTap: _busy ? null : _delete,
            ),
          ],
        ),
        const SizedBox(height: Space.lg),
        if (_busy) const Center(child: CircularProgressIndicator()),
        Text(
          'Need a copy of your data? Email us from Help & FAQ and we’ll send '
          'it within 30 days.',
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
