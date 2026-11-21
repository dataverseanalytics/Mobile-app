import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../state/providers.dart';
import 'meal_view.dart';

/// A meal already in the diary: read-only breakdown, share and delete.
class MealDetailScreen extends ConsumerWidget {
  const MealDetailScreen({super.key, required this.mealId});
  final String mealId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meal = ref
        .watch(diaryProvider)
        .where((m) => m.id == mealId)
        .firstOrNull;

    if (meal == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Meal not found',
            message: 'It may have been deleted.',
            actionLabel: 'Back to today',
            onAction: () => context.go(Routes.today),
          ),
        ),
      );
    }

    void delete() {
      final diary = ref.read(diaryProvider.notifier);
      final messenger = ScaffoldMessenger.of(context);
      diary.remove(meal.id);
      context.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Deleted ${meal.name}'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => diary.restore(meal),
            ),
          ),
        );
    }

    return MealScrollView(
      meal: meal,
      heroTag: 'meal-photo-${meal.id}',
      showConfidence: false,
      leading: GlassIconButton(
        icon: Icons.arrow_back_rounded,
        tooltip: 'Back',
        onPressed: () => context.pop(),
      ),
      actions: [
        GlassIconButton(
          icon: Icons.ios_share_rounded,
          tooltip: 'Share',
          onPressed: () => context.push(Routes.share(meal.id)),
        ),
      ],
      belowItems: [
        const SizedBox(height: Space.md),
        OutlinedButton.icon(
          onPressed: delete,
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Delete meal'),
        ),
      ],
    );
  }
}
