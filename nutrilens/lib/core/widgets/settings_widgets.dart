import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/theme_x.dart';
import '../theme/tokens.dart';

/// Large-title page used by every settings screen.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.title,
    required this.children,
    this.actions = const [],
    this.bottom,
  });

  final String title;
  final List<Widget> children;
  final List<Widget> actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: bottom,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(title),
            actions: [
              ...actions,
              const SizedBox(width: Space.sm),
            ],
            leading: context.canPop()
                ? IconButton(
                    onPressed: () => context.pop(),
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back_rounded),
                  )
                : null,
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              Space.gutter,
              0,
              Space.gutter,
              MediaQuery.paddingOf(context).bottom + Space.xxxl,
            ),
            sliver: SliverList.list(children: children),
          ),
        ],
      ),
    );
  }
}

class GroupLabel extends StatelessWidget {
  const GroupLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xs, Space.xxl, 0, Space.sm),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: context.text.labelSmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Rounded card holding rows separated by hairlines.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.brand.card,
        borderRadius: Radii.xlAll,
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: Radii.xlAll,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(indent: 56),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.dot,
    this.value,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? dot;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final fg = destructive ? context.colors.error : context.colors.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.lg,
              vertical: Space.sm,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: dot != null
                      ? Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: dot,
                              shape: BoxShape.circle,
                            ),
                            child: const SizedBox.square(dimension: 10),
                          ),
                        )
                      : Icon(
                          icon,
                          size: 22,
                          color: destructive
                              ? context.colors.error
                              : context.colors.onSurfaceVariant,
                        ),
                ),
                const SizedBox(width: Space.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.text.bodyLarge?.copyWith(color: fg),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: context.text.bodySmall?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(width: Space.sm),
                  Text(
                    value!,
                    style: context.text.titleSmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
                ?trailing,
                if (onTap != null && trailing == null) ...[
                  const SizedBox(width: Space.xs),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.colors.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Confirmation dialog whose confirm button names the action.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog.adaptive(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(
            foregroundColor: destructive ? ctx.colors.error : null,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}
