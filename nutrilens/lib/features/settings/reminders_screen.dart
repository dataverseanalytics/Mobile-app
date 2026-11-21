import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/settings_widgets.dart';
import '../../data/account.dart';
import '../../state/providers.dart';

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  static const _icons = {
    'breakfast': Icons.wb_twilight_rounded,
    'lunch': Icons.wb_sunny_rounded,
    'dinner': Icons.nightlight_round,
    'weigh-in': Icons.monitor_weight_outlined,
  };

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref,
    Reminder r,
  ) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: r.hour, minute: r.minute),
      helpText: '${r.label} reminder',
    );
    if (t != null) {
      ref
          .read(remindersProvider.notifier)
          .update(r.copyWith(hour: t.hour, minute: t.minute, enabled: true));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(remindersProvider);
    final n = ref.read(remindersProvider.notifier);
    final anyOn = reminders.any((r) => r.enabled);

    return SettingsPage(
      title: 'Reminders',
      children: [
        Text(
          'Gentle nudges so you never forget to log. People who log every '
          'meal reach their goal far more often.',
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Space.lg),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.notifications_active_outlined,
              title: 'All reminders',
              trailing: Switch.adaptive(value: anyOn, onChanged: n.setAll),
              onTap: () => n.setAll(!anyOn),
            ),
          ],
        ),
        const GroupLabel('Schedule'),
        SettingsGroup(
          children: [
            for (final r in reminders)
              SettingsRow(
                key: ValueKey(r.id),
                icon: _icons[r.id] ?? Icons.alarm_rounded,
                title: r.label,
                subtitle: TimeOfDay(
                  hour: r.hour,
                  minute: r.minute,
                ).format(context),
                trailing: Switch.adaptive(
                  value: r.enabled,
                  onChanged: (v) => n.update(r.copyWith(enabled: v)),
                ),
                onTap: () => _pickTime(context, ref, r),
              ),
          ],
        ),
        const SizedBox(height: Space.md),
        Text(
          'Tap a reminder to change its time.',
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
