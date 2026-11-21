import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/format.dart';
import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/macro_widgets.dart';
import '../../core/widgets/meal_tile.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../scan/scan_launcher.dart';

class DiaryScreen extends ConsumerWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(selectedDayProvider);
    final meals = ref.watch(mealsForDayProvider(day));
    final isToday = day == dateOnly(DateTime.now());
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(isToday ? 'Diary' : Fmt.longDate(day)),
            actions: [
              IconButton(
                onPressed: () => showLogSheet(context, ref),
                tooltip: 'Log a meal',
                icon: const Icon(Icons.add_rounded),
              ),
              const SizedBox(width: Space.sm),
            ],
          ),
          const SliverToBoxAdapter(child: _DateStrip()),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(
              Space.gutter,
              Space.lg,
              Space.gutter,
              0,
            ),
            sliver: SliverToBoxAdapter(child: _DaySummary()),
          ),
          for (final type in MealType.values) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                type: type,
                kcal: meals
                    .where((m) => m.type == type)
                    .fold(0.0, (a, m) => a + m.kcal),
                onAdd: () => showLogSheet(context, ref),
              ),
            ),
            _SectionBody(
              meals: meals.where((m) => m.type == type).toList(),
              type: type,
              onAdd: () => showLogSheet(context, ref),
            ),
          ],
          SliverToBoxAdapter(child: SizedBox(height: bottomInset + Space.xxxl)),
        ],
      ),
    );
  }
}

class _DateStrip extends ConsumerWidget {
  const _DateStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDayProvider);
    final today = dateOnly(DateTime.now());
    return SizedBox(
      height: 76,
      child: ListView.separated(
        reverse: true,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        itemCount: 30,
        separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
        itemBuilder: (context, i) {
          final d = today.subtract(Duration(days: i));
          final sel = d == selected;
          final hasMeals = ref.watch(mealsForDayProvider(d)).isNotEmpty;
          final c = context.colors;
          return Semantics(
            selected: sel,
            button: true,
            label: Fmt.longDate(d),
            excludeSemantics: true,
            child: InkWell(
              onTap: () => ref.read(selectedDayProvider.notifier).select(d),
              borderRadius: Radii.lgAll,
              child: AnimatedContainer(
                duration: Motion.fast,
                width: 52,
                decoration: BoxDecoration(
                  color: sel ? c.onSurface : context.brand.card,
                  borderRadius: Radii.lgAll,
                  border: Border.all(
                    color: sel ? c.onSurface : c.outlineVariant,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      Fmt.weekdayShort(d),
                      style: context.text.labelSmall?.copyWith(
                        color: sel
                            ? c.surface.withValues(alpha: 0.7)
                            : c.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Space.xxs),
                    Text(
                      '${d.day}',
                      style: context.text.titleMedium?.copyWith(
                        color: sel ? c.surface : c.onSurface,
                      ),
                    ),
                    const SizedBox(height: Space.xxs),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: hasMeals
                            ? (sel ? context.brand.accent : c.onSurface)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox.square(dimension: 5),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DaySummary extends ConsumerWidget {
  const _DaySummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(selectedDayProvider);
    final eaten = ref.watch(dayMacrosProvider(day));
    final goal = ref.watch(targetsProvider).kcal;
    final p = (eaten.kcal / goal).clamp(0.0, 1.0);
    final over = eaten.kcal > goal;
    return AppCard(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(Fmt.kcal(eaten.kcal), style: context.text.headlineMedium),
              const SizedBox(width: Space.xs),
              Text(
                '/ ${Fmt.kcal(goal)} kcal',
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Pill(
                label: over
                    ? '${Fmt.kcal(eaten.kcal - goal)} over'
                    : '${Fmt.kcal(goal - eaten.kcal)} left',
                background: over
                    ? context.colors.error.withValues(alpha: 0.12)
                    : context.colors.surfaceContainerHigh,
                foreground: over ? context.colors.error : null,
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          ClipRRect(
            borderRadius: Radii.pillAll,
            child: LinearProgressIndicator(
              value: p,
              minHeight: 8,
              color: over ? context.colors.error : context.colors.onSurface,
            ),
          ),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.lg,
            children: [
              MacroDot(kind: MacroKind.protein, grams: eaten.protein),
              MacroDot(kind: MacroKind.carbs, grams: eaten.carbs),
              MacroDot(kind: MacroKind.fat, grams: eaten.fat),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.type,
    required this.kcal,
    required this.onAdd,
  });
  final MealType type;
  final double kcal;
  final VoidCallback onAdd;

  static const _icons = {
    MealType.breakfast: Icons.wb_twilight_rounded,
    MealType.lunch: Icons.wb_sunny_rounded,
    MealType.dinner: Icons.nightlight_round,
    MealType.snack: Icons.cookie_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.xxl,
        Space.sm,
        Space.sm,
      ),
      child: Row(
        children: [
          Icon(_icons[type], size: 20, color: context.colors.onSurfaceVariant),
          const SizedBox(width: Space.sm),
          Semantics(
            header: true,
            child: Text(type.label, style: context.text.titleMedium),
          ),
          const SizedBox(width: Space.sm),
          if (kcal > 0)
            Text(
              '${Fmt.kcal(kcal)} kcal',
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          const Spacer(),
          IconButton(
            onPressed: onAdd,
            tooltip: 'Add to ${type.label.toLowerCase()}',
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _SectionBody extends StatelessWidget {
  const _SectionBody({
    required this.meals,
    required this.type,
    required this.onAdd,
  });
  final List<Meal> meals;
  final MealType type;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (meals.isEmpty) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        sliver: SliverToBoxAdapter(
          child: Material(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: Radii.xlAll,
              side: BorderSide(
                color: context.colors.outlineVariant,
                width: 1.5,
              ),
            ),
            child: InkWell(
              onTap: onAdd,
              customBorder: const RoundedRectangleBorder(
                borderRadius: Radii.xlAll,
              ),
              child: Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: Row(
                  children: [
                    Icon(
                      Icons.photo_camera_outlined,
                      color: context.colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: Space.md),
                    Text(
                      'Log your ${type.label.toLowerCase()}',
                      style: context.text.bodyMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      sliver: SliverList.separated(
        itemCount: meals.length,
        separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
        itemBuilder: (context, i) => MealTile(
          key: ValueKey(meals[i].id),
          meal: meals[i],
          onTap: () => context.push(Routes.meal(meals[i].id)),
        ),
      ),
    );
  }
}
