import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/macro_widgets.dart';
import '../../core/widgets/pressable.dart';
import '../../data/ai_repository.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../scan/edit_item_sheet.dart';

const _cardWidth = 248.0;
const _cardHeight = 212.0;

/// Horizontal carousel of AI meal ideas that fit the rest of today's budget.
class SuggestionCarousel extends ConsumerWidget {
  const SuggestionCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targets = ref.watch(targetsProvider);
    final eaten = ref.watch(dayMacrosProvider(dateOnly(DateTime.now())));
    double left(double target, double used) =>
        (target - used).clamp(0, double.infinity).toDouble();
    final kcalLeft = left(targets.kcal, eaten.kcal);
    final proteinLeft = left(targets.macros.protein, eaten.protein);
    final key = (
      // Rounded so logging a snack doesn't trigger a new AI request.
      kcal: (kcalLeft / 50).round() * 50,
      protein: (proteinLeft / 5).round() * 5,
      carbs: (left(targets.macros.carbs, eaten.carbs) / 5).round() * 5,
      fat: (left(targets.macros.fat, eaten.fat) / 5).round() * 5,
      meal: MealType.forTime(DateTime.now()),
    );
    final ideas = ref.watch(aiSuggestionsProvider(key));

    final Widget body;
    if (kcalLeft < 80) {
      body = const _Message(
        icon: Icons.check_circle_outline_rounded,
        text: "You've reached today's calorie target. Water or a herbal tea are good picks now.",
      );
    } else {
      body = switch (ideas) {
        AsyncData(:final value) when value.isEmpty => const _Message(
          icon: Icons.restaurant_menu_rounded,
          text: 'No ideas fit what’s left today — a piece of fruit is a safe bet.',
        ),
        AsyncData(:final value) => _List(
          count: value.length,
          builder: (i) => _SuggestionCard(
            idea: value[i],
            fits: value[i].macros.kcal <= kcalLeft,
          ),
        ),
        AsyncError(:final error) => _Message(
          icon: Icons.cloud_off_rounded,
          text: error is AiFailure
              ? error.message
              : "Couldn't load ideas right now.",
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(aiSuggestionsProvider(key)),
        ),
        _ => _List(count: 3, builder: (_) => const _SkeletonCard()),
      };
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            0,
            Space.gutter,
            Space.md,
          ),
          child: Text(
            'You have ${Fmt.kcal(kcalLeft)} kcal and ${proteinLeft.round()} g protein left today.',
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
        body,
      ],
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.count, required this.builder});
  final int count;
  final Widget Function(int i) builder;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _cardHeight,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(width: Space.md),
      itemBuilder: (_, i) => builder(i),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: context.brand.card,
        borderRadius: Radii.xlAll,
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Row(
          children: [
            Icon(icon, color: context.colors.onSurfaceVariant),
            const SizedBox(width: Space.md),
            Expanded(child: Text(text, style: context.text.bodyMedium)),
            if (actionLabel != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    ),
  );
}

class _SuggestionCard extends ConsumerWidget {
  const _SuggestionCard({required this.idea, required this.fits});

  final AiSuggestion idea;
  final bool fits;

  Future<void> _log(BuildContext context, WidgetRef ref) async {
    final item = FoodItem(
      id: 'ai-${DateTime.now().microsecondsSinceEpoch}',
      name: idea.title,
      unit: idea.portion,
      macros: idea.macros,
      confidence: 0.8,
    );
    final result = await showEditItemSheet(context, item, adding: true);
    if (result is! EditServings || !context.mounted) return;
    final chosen = item.copyWith(servings: result.servings);
    unawaited(HapticFeedback.mediumImpact());
    final now = DateTime.now();
    ref
        .read(diaryProvider.notifier)
        .add(
          Meal(
            id: 'meal-${now.microsecondsSinceEpoch}',
            name: idea.title,
            loggedAt: now,
            type: MealType.forTime(now),
            items: [chosen],
          ),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${idea.title} logged · ${Fmt.kcal(chosen.kcal)} kcal'),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final macros = idea.macros;
    return Pressable(
      onTap: () => _log(context, ref),
      semanticLabel:
          '${idea.title}, ${idea.portion}, ${Fmt.kcal(macros.kcal)} calories. ${idea.why}. Double tap to log.',
      child: SizedBox(
        width: _cardWidth,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.brand.card,
            borderRadius: Radii.xlAll,
            border: Border.all(color: context.colors.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Pill(
                        label: fits ? 'Fits your day' : 'A little over',
                        icon: fits
                            ? Icons.check_rounded
                            : Icons.info_outline_rounded,
                        background: fits
                            ? context.brand.accent
                            : context.colors.surfaceContainerHigh,
                        foreground: fits
                            ? context.brand.onAccent
                            : context.colors.onSurface,
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    if (idea.vegetarian)
                      Tooltip(
                        message: 'Vegetarian',
                        child: Icon(
                          Icons.eco_rounded,
                          size: 18,
                          color: context.colors.primary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Space.md),
                Text(
                  idea.title,
                  style: context.text.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Space.xxs),
                Text(
                  '${idea.portion} · ${Fmt.kcal(macros.kcal)} kcal',
                  style: context.text.labelMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Space.sm),
                Expanded(
                  child: Text(
                    idea.why,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: Space.md,
                        children: [
                          MacroDot(
                            kind: MacroKind.protein,
                            grams: macros.protein,
                          ),
                          MacroDot(kind: MacroKind.carbs, grams: macros.carbs),
                          MacroDot(kind: MacroKind.fat, grams: macros.fat),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.add_circle_rounded,
                      color: context.colors.onSurface,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHigh,
        borderRadius: Radii.smAll,
      ),
      child: SizedBox(width: w, height: h),
    );
    return Semantics(
      label: 'Loading meal ideas',
      child: SizedBox(
        width: _cardWidth,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.brand.card,
            borderRadius: Radii.xlAll,
            border: Border.all(color: context.colors.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(96, 24),
                const SizedBox(height: Space.lg),
                bar(180, 16),
                const SizedBox(height: Space.sm),
                bar(120, 12),
                const SizedBox(height: Space.lg),
                bar(200, 10),
                const SizedBox(height: Space.xs),
                bar(160, 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
