import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../state/providers.dart';
import '../onboarding/onboarding_widgets.dart';
import 'charts.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weights = ref.watch(weightLogProvider);
    final profile = ref.watch(profileProvider);
    final targets = ref.watch(targetsProvider);
    final streak = ref.watch(streakProvider);
    final today = dateOnly(DateTime.now());
    final days = [
      for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i)),
    ];
    final kcals = [for (final d in days) ref.watch(dayMacrosProvider(d)).kcal];
    final proteins = [
      for (final d in days) ref.watch(dayMacrosProvider(d)).protein,
    ];
    final mealsLogged = ref.watch(diaryProvider).length;
    final avgKcal = kcals.reduce((a, b) => a + b) / kcals.length;
    final avgProtein = proteins.reduce((a, b) => a + b) / proteins.length;
    final proteinHits = proteins
        .where((p) => p >= targets.macros.protein * 0.9)
        .length;
    final change = weights.last - weights.first;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('Progress')),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            sliver: SliverList.list(
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Weight',
                                  style: context.text.labelMedium?.copyWith(
                                    color: context.colors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: Space.xs),
                                Text.rich(
                                  TextSpan(
                                    text: weights.last.toStringAsFixed(1),
                                    style: context.text.headlineLarge,
                                    children: [
                                      TextSpan(
                                        text: ' kg',
                                        style: context.text.titleMedium
                                            ?.copyWith(
                                              color: context
                                                  .colors
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (weights.length >= 2)
                            Pill(
                              icon: change <= 0
                                  ? Icons.trending_down_rounded
                                  : Icons.trending_up_rounded,
                              label:
                                  '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)} kg',
                              background: context.brand.success.withValues(
                                alpha: 0.14,
                              ),
                              foreground: context.brand.success,
                            ),
                        ],
                      ),
                      const SizedBox(height: Space.xl),
                      if (weights.length >= 2)
                        WeightChart(
                          values: weights,
                          goal: profile.targetWeightKg,
                        )
                      else
                        const _WeightChartEmpty(),
                      const SizedBox(height: Space.lg),
                      Row(
                        children: [
                          Icon(
                            Icons.flag_rounded,
                            size: 18,
                            color: context.brand.success,
                          ),
                          const SizedBox(width: Space.xs),
                          Expanded(
                            child: Text(
                              'Goal ${profile.targetWeightKg.toStringAsFixed(1)} kg · '
                              '${(weights.last - profile.targetWeightKg).abs().toStringAsFixed(1)} kg to go',
                              style: context.text.bodySmall?.copyWith(
                                color: context.colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          FilledButton.tonal(
                            onPressed: () =>
                                _logWeight(context, ref, weights.last),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              backgroundColor:
                                  context.colors.surfaceContainerHigh,
                              foregroundColor: context.colors.onSurface,
                            ),
                            child: const Text('Log weight'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calories this week',
                        style: context.text.titleMedium,
                      ),
                      const SizedBox(height: Space.xxs),
                      Text(
                        'Line shows your ${Fmt.kcal(targets.kcal)} kcal goal',
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: Space.xl),
                      WeekBars(
                        values: kcals,
                        labels: [
                          for (final d in days)
                            Fmt.weekdayShort(d).substring(0, 1),
                        ],
                        goal: targets.kcal,
                        highlight: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.md),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: Space.md,
                  crossAxisSpacing: Space.md,
                  childAspectRatio: 1.45,
                  children: [
                    _StatTile(
                      icon: Icons.local_fire_department_rounded,
                      value: Fmt.kcal(avgKcal),
                      label: 'Avg kcal / day',
                    ),
                    _StatTile(
                      icon: Icons.egg_alt_rounded,
                      value: '${avgProtein.round()} g',
                      label: 'Avg protein / day',
                    ),
                    _StatTile(
                      icon: Icons.bolt_rounded,
                      value: '$streak days',
                      label: 'Current streak',
                      highlight: true,
                    ),
                    _StatTile(
                      icon: Icons.photo_library_rounded,
                      value: '$mealsLogged',
                      label: 'Meals logged',
                    ),
                  ],
                ),
                const SizedBox(height: Space.md),
                AppCard(
                  padding: const EdgeInsets.all(Space.lg),
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
                            Icons.auto_awesome_rounded,
                            color: context.brand.onAccent,
                          ),
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Text(
                          'You hit your protein goal on $proteinHits of the last 7 days. '
                          '${proteinHits >= 5 ? 'Brilliant consistency!' : 'Try adding eggs, dal or yogurt to breakfast.'}',
                          style: context.text.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: bottomInset + Space.xxxl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logWeight(
    BuildContext context,
    WidgetRef ref,
    double current,
  ) async {
    var value = current;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            0,
            Space.gutter,
            Space.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Today's weight", style: ctx.text.headlineSmall),
              const SizedBox(height: Space.lg),
              ValuePicker(
                label: 'Weight',
                value: value,
                unit: 'kg',
                min: 35,
                max: 200,
                step: 0.1,
                decimals: 1,
                onChanged: (v) => setSheet(() => value = v),
              ),
              const SizedBox(height: Space.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved == true) {
      ref
          .read(weightLogProvider.notifier)
          .log(double.parse(value.toStringAsFixed(1)));
    }
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    this.highlight = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final bg = highlight ? context.brand.accent : context.brand.card;
    final fg = highlight ? context.brand.onAccent : context.colors.onSurface;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: Radii.xlAll,
          border: highlight
              ? null
              : Border.all(color: context.colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: fg, size: 22),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: context.text.titleLarge?.copyWith(color: fg),
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(
                      color: highlight
                          ? fg.withValues(alpha: 0.7)
                          : context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeightChartEmpty extends StatelessWidget {
  const _WeightChartEmpty();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surfaceContainer,
        borderRadius: Radii.lgAll,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Row(
          children: [
            Icon(
              Icons.show_chart_rounded,
              color: context.colors.onSurfaceVariant,
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text(
                'Log your weight once a week and your trend will appear here.',
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
