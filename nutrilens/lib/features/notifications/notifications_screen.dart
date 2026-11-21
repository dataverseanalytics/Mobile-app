import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/settings_widgets.dart';
import '../../data/account.dart';
import '../../state/providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notices = ref.watch(noticesProvider);
    final unread = ref.watch(unreadNoticesProvider);
    final n = ref.read(noticesProvider.notifier);

    return SettingsPage(
      title: 'Notifications',
      actions: [
        if (unread > 0)
          TextButton(
            onPressed: n.markAllRead,
            child: const Text('Mark all read'),
          ),
      ],
      children: [
        if (notices.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: Space.huge),
            child: EmptyState(
              icon: Icons.notifications_none_rounded,
              title: "You're all caught up",
              message:
                  'Streak updates, weekly reports and tips will appear here.',
            ),
          )
        else
          for (final notice in notices)
            Padding(
              key: ValueKey(notice.id),
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Dismissible(
                key: ValueKey('d-${notice.id}'),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => n.dismiss(notice.id),
                background: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.colors.surfaceContainerHigh,
                    borderRadius: Radii.lgAll,
                  ),
                  child: const Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.only(right: Space.xl),
                      child: Icon(Icons.done_all_rounded),
                    ),
                  ),
                ),
                child: _NoticeTile(
                  notice: notice,
                  onTap: () => n.markRead(notice.id),
                ),
              ),
            ),
      ],
    );
  }
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({required this.notice, required this.onTap});
  final AppNotice notice;
  final VoidCallback onTap;

  IconData get _icon => switch (notice.kind) {
    NoticeKind.welcome => Icons.waving_hand_rounded,
    NoticeKind.tip => Icons.lightbulb_outline_rounded,
    NoticeKind.streak => Icons.local_fire_department_rounded,
    NoticeKind.report => Icons.insights_rounded,
    NoticeKind.pro => Icons.workspace_premium_rounded,
  };

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return Fmt.dayMonth(t);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: notice.read ? context.brand.card : context.colors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.lgAll,
        side: BorderSide(color: context.colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: notice.read
                      ? context.colors.surfaceContainerHigh
                      : context.brand.accent,
                  borderRadius: Radii.mdAll,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(Space.sm),
                  child: Icon(
                    _icon,
                    size: 20,
                    color: notice.read
                        ? context.colors.onSurface
                        : context.brand.onAccent,
                  ),
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notice.title,
                            style: context.text.titleSmall,
                          ),
                        ),
                        Text(
                          _ago(notice.createdAt),
                          style: context.text.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      notice.body,
                      style: context.text.bodyMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (!notice.read) ...[
                const SizedBox(width: Space.sm),
                Padding(
                  padding: const EdgeInsets.only(top: Space.xs),
                  child: Semantics(
                    label: 'Unread',
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: context.colors.error,
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox.square(dimension: 8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
