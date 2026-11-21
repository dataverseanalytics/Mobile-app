import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/food_photo.dart';
import '../../core/widgets/macro_widgets.dart';
import '../../data/models.dart';

/// Shared layout for a scan result and a logged meal: hero photo,
/// totals, health score and the list of recognised items.
class MealScrollView extends StatelessWidget {
  const MealScrollView({
    super.key,
    required this.meal,
    required this.heroTag,
    required this.leading,
    this.actions = const [],
    this.onItemTap,
    this.onItemRemove,
    this.belowItems = const [],
    this.bottomBar,
    this.showConfidence = true,
  });

  final Meal meal;
  final String heroTag;
  final Widget leading;
  final List<Widget> actions;
  final ValueChanged<FoodItem>? onItemTap;
  final ValueChanged<FoodItem>? onItemRemove;
  final List<Widget> belowItems;
  final Widget? bottomBar;
  final bool showConfidence;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final photoH = (size.height * 0.42).clamp(260.0, 420.0);
    final m = meal.macros;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        bottomNavigationBar: bottomBar,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: photoH,
              pinned: true,
              stretch: true,
              automaticallyImplyLeading: false,
              backgroundColor: context.colors.surface,
              leading: Padding(
                padding: const EdgeInsets.only(left: Space.sm),
                child: Center(child: leading),
              ),
              leadingWidth: 64,
              actions: [
                ...actions,
                const SizedBox(width: Space.sm),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: heroTag,
                      child: FoodPhoto(
                        meal.photo,
                        width: size.width,
                        semanticLabel: 'Photo of ${meal.name}',
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0, 0.3, 0.75, 1],
                          colors: [
                            Colors.black.withValues(alpha: 0.45),
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.25),
                          ],
                        ),
                      ),
                    ),
                    // Rounded lip so the content sheet appears to overlap
                    // the photo without sliding under the pinned app bar.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: -1,
                      height: Radii.xl + 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(Radii.xl),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.xxl,
                  Space.gutter,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${meal.type.label.toUpperCase()} · ${Fmt.time(meal.loggedAt)}',
                      style: context.text.labelSmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    Semantics(
                      header: true,
                      child: Text(
                        meal.name,
                        style: context.text.headlineMedium,
                      ),
                    ),
                    const SizedBox(height: Space.md),
                    Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.sm,
                      children: [
                        if (showConfidence)
                          Pill(
                            icon: Icons.auto_awesome_rounded,
                            label:
                                '${(meal.confidence * 100).round()}% confident',
                          ),
                        Pill(
                          icon: Icons.restaurant_menu_rounded,
                          label: '${meal.items.length} items',
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.xl),
                    _TotalsCard(kcal: meal.kcal, macros: m),
                    const SizedBox(height: Space.md),
                    HealthScoreCard(score: meal.healthScore),
                    const SizedBox(height: Space.xxl),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Detected items',
                            style: context.text.titleLarge,
                          ),
                        ),
                        if (onItemTap != null)
                          Text(
                            'Tap to adjust',
                            style: context.text.bodySmall?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: Space.md),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              sliver: SliverList.separated(
                itemCount: meal.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                itemBuilder: (context, i) {
                  final item = meal.items[i];
                  final row = ItemRow(
                    item: item,
                    showConfidence: showConfidence,
                    onTap: onItemTap == null ? null : () => onItemTap!(item),
                  );
                  if (onItemRemove == null) return row;
                  return Dismissible(
                    key: ValueKey(item.id),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => onItemRemove!(item),
                    background: DecoratedBox(
                      decoration: BoxDecoration(
                        color: context.colors.error,
                        borderRadius: Radii.lgAll,
                      ),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: Space.xl),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: context.colors.onError,
                          ),
                        ),
                      ),
                    ),
                    child: row,
                  );
                },
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.md,
                Space.gutter,
                Space.xxxl,
              ),
              sliver: SliverList.list(children: belowItems),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.kcal, required this.macros});
  final double kcal;
  final Macros macros;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppCard(
          color: context.isDark ? context.brand.card : const Color(0xFF14140F),
          padding: const EdgeInsets.symmetric(
            horizontal: Space.xl,
            vertical: Space.lg,
          ),
          child: Semantics(
            label: '${Fmt.kcal(kcal)} calories in total',
            excludeSemantics: true,
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.brand.accent,
                    borderRadius: Radii.mdAll,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(Space.sm),
                    child: Icon(
                      Icons.local_fire_department_rounded,
                      color: context.brand.onAccent,
                    ),
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Text(
                    'Calories',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: Space.sm),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: kcal),
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : Motion.ring,
                      curve: Motion.enter,
                      builder: (_, v, _) => Text(
                        Fmt.kcal(v),
                        style: context.text.headlineLarge?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Space.xs),
                Padding(
                  padding: const EdgeInsets.only(top: Space.sm),
                  child: Text(
                    'kcal',
                    style: context.text.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.sm),
        Row(
          children: [
            for (final k in MacroKind.values) ...[
              if (k != MacroKind.protein) const SizedBox(width: Space.sm),
              Expanded(
                child: MacroTile(kind: k, grams: k.of(macros)),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class HealthScoreCard extends StatelessWidget {
  const HealthScoreCard({super.key, required this.score});
  final double score;

  @override
  Widget build(BuildContext context) {
    final (color, verdict) = switch (score) {
      >= 8 => (
        context.brand.success,
        'Great balance — protein, fibre and healthy fats.',
      ),
      >= 6 => (
        context.brand.warning,
        'Solid choice. Add veggies to boost fibre.',
      ),
      _ => (
        context.colors.error,
        'A treat meal. Balance it with a lighter next meal.',
      ),
    };
    return AppCard(
      padding: const EdgeInsets.all(Space.lg),
      child: Semantics(
        label: 'Health score ${score.toStringAsFixed(1)} out of 10. $verdict',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.favorite_rounded, color: color, size: 20),
                const SizedBox(width: Space.sm),
                Text('Health score', style: context.text.titleSmall),
                const Spacer(),
                Text.rich(
                  TextSpan(
                    text: score.toStringAsFixed(1),
                    style: context.text.titleLarge,
                    children: [
                      TextSpan(
                        text: ' / 10',
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.md),
            Row(
              children: [
                for (var i = 0; i < 10; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  Expanded(
                    child: AnimatedContainer(
                      duration: Motion.base,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i < score.round()
                            ? color
                            : context.brand.ringTrack,
                        borderRadius: Radii.pillAll,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: Space.md),
            Text(
              verdict,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ItemRow extends StatelessWidget {
  const ItemRow({
    super.key,
    required this.item,
    this.onTap,
    this.showConfidence = true,
  });

  final FoodItem item;
  final VoidCallback? onTap;
  final bool showConfidence;

  @override
  Widget build(BuildContext context) {
    final low = item.confidence < 0.8;
    final portion = item.servings == 1
        ? item.unit
        : '${Fmt.servings(item.servings)} × ${item.unit}';
    return Material(
      color: context.brand.card,
      shape: RoundedRectangleBorder(
        borderRadius: Radii.lgAll,
        side: BorderSide(
          color: low && showConfidence
              ? context.brand.warning.withValues(alpha: 0.6)
              : context.colors.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.lg,
            vertical: Space.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: context.text.titleSmall),
                    const SizedBox(height: Space.xxs),
                    Text(
                      portion,
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    if (low && showConfidence) ...[
                      const SizedBox(height: Space.xs),
                      Row(
                        children: [
                          Icon(
                            Icons.help_outline_rounded,
                            size: 14,
                            color: context.brand.warning,
                          ),
                          const SizedBox(width: Space.xs),
                          Flexible(
                            child: Text(
                              'Not sure — tap to check',
                              style: context.text.bodySmall?.copyWith(
                                color: context.brand.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Space.md),
              Text(
                '${Fmt.kcal(item.kcal)} kcal',
                style: context.text.labelLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (onTap != null) ...[
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
    );
  }
}
