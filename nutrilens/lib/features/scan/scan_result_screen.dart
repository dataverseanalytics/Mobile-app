import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/format.dart';
import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../meal/meal_view.dart';
import 'edit_item_sheet.dart';

class ScanResultScreen extends ConsumerWidget {
  const ScanResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meal = ref.watch(scanDraftProvider);
    if (meal == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: EmptyState(
            icon: Icons.photo_camera_rounded,
            title: 'No scan in progress',
            message:
                'Take a photo of your meal to see its calories and macros.',
            actionLabel: 'Back to today',
            onAction: () => context.go(Routes.today),
          ),
        ),
      );
    }

    final draft = ref.read(scanDraftProvider.notifier);

    Future<void> edit(FoodItem item) async {
      final r = await showEditItemSheet(context, item);
      switch (r) {
        case EditServings(:final servings):
          draft.updateItem(item.id, servings);
        case EditRemove():
          draft.removeItem(item.id);
        case null:
          break;
      }
    }

    void remove(FoodItem item) {
      draft.removeItem(item.id);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Removed ${item.name}'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => draft.addItem(item),
            ),
          ),
        );
    }

    void log() {
      HapticFeedback.mediumImpact();
      ref
          .read(diaryProvider.notifier)
          .add(meal.copyWith(loggedAt: DateTime.now()));
      draft.clear();
      final messenger = ScaffoldMessenger.of(context);
      final router = GoRouter.of(context);
      router.go(Routes.today);
      messenger.showSnackBar(
        SnackBar(
          content: Text('${meal.name} logged · ${Fmt.kcal(meal.kcal)} kcal'),
          action: SnackBarAction(
            label: 'Share',
            onPressed: () => router.push(Routes.share(meal.id)),
          ),
        ),
      );
    }

    return MealScrollView(
      meal: meal,
      heroTag: 'scan-${meal.id}',
      leading: GlassIconButton(
        icon: Icons.close_rounded,
        tooltip: 'Discard scan',
        onPressed: () {
          draft.clear();
          context.pop();
        },
      ),
      actions: [
        GlassIconButton(
          icon: Icons.ios_share_rounded,
          tooltip: 'Share',
          onPressed: () => context.push(Routes.share('draft')),
        ),
      ],
      onItemTap: edit,
      onItemRemove: remove,
      belowItems: [
        OutlinedButton.icon(
          onPressed: () => context.push('${Routes.search}?addTo=draft'),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add a missing item'),
        ),
        const SizedBox(height: Space.xxl),
        Text('Log as', style: context.text.titleMedium),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final t in MealType.values)
              ChoiceChip(
                label: Text(t.label),
                selected: meal.type == t,
                onSelected: (_) => draft.setType(t),
                labelStyle: context.text.labelMedium?.copyWith(
                  color: meal.type == t
                      ? context.colors.surface
                      : context.colors.onSurface,
                ),
              ),
          ],
        ),
      ],
      bottomBar: _LogBar(
        kcal: meal.kcal,
        enabled: meal.items.isNotEmpty,
        onLog: log,
      ),
    );
  }
}

class _LogBar extends StatelessWidget {
  const _LogBar({
    required this.kcal,
    required this.enabled,
    required this.onLog,
  });
  final double kcal;
  final bool enabled;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.md,
            Space.gutter,
            Space.md,
          ),
          child: FilledButton(
            onPressed: enabled ? onLog : null,
            child: Text(
              enabled
                  ? 'Log meal · ${Fmt.kcal(kcal)} kcal'
                  : 'Add at least one item',
            ),
          ),
        ),
      ),
    );
  }
}
