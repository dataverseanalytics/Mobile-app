import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../format.dart';
import '../theme/theme_x.dart';
import '../theme/tokens.dart';
import 'food_photo.dart';
import 'macro_widgets.dart';
import 'pressable.dart';

/// A logged meal: photo, name, time and macros, kcal on the right.
class MealTile extends StatelessWidget {
  const MealTile({super.key, required this.meal, this.onTap});
  final Meal meal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final m = meal.macros;
    return Pressable(
      onTap: onTap,
      semanticLabel:
          '${meal.name}, ${meal.type.label} at ${Fmt.time(meal.loggedAt)}, '
          '${Fmt.kcal(meal.kcal)} calories',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.brand.card,
          borderRadius: Radii.xlAll,
          border: Border.all(color: context.colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Space.sm),
          child: Row(
            children: [
              Hero(
                tag: 'meal-photo-${meal.id}',
                child: FoodPhoto(
                  meal.photo,
                  width: 76,
                  height: 76,
                  radius: Radii.lgAll,
                ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${meal.type.label} · ${Fmt.time(meal.loggedAt)}',
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: Space.xxs),
                      Text(
                        meal.name,
                        style: context.text.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: Space.sm),
                      Wrap(
                        spacing: Space.md,
                        runSpacing: Space.xs,
                        children: [
                          MacroDot(kind: MacroKind.protein, grams: m.protein),
                          MacroDot(kind: MacroKind.carbs, grams: m.carbs),
                          MacroDot(kind: MacroKind.fat, grams: m.fat),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: Space.sm),
              ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.only(right: Space.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Fmt.kcal(meal.kcal),
                        style: context.text.titleLarge?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        'kcal',
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
