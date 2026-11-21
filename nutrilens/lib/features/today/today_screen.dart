import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/format.dart';
import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/calorie_ring.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/macro_widgets.dart';
import '../../core/widgets/meal_tile.dart';
import '../../state/providers.dart';
import '../scan/scan_launcher.dart';
import 'suggestion_card.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = dateOnly(DateTime.now());
    final meals = ref.watch(mealsForDayProvider(today));
    final premium = ref.watch(premiumProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverSafeArea(
            bottom: false,
            sliver: SliverToBoxAdapter(child: _Header()),
          ),
          const SliverToBoxAdapter(child: _WeekStrip()),
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(
              Space.gutter,
              Space.lg,
              Space.gutter,
              0,
            ),
            sliver: SliverToBoxAdapter(child: _CaloriesCard()),
          ),
          if (!premium)
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(
                Space.gutter,
                Space.md,
                Space.gutter,
                0,
              ),
              sliver: SliverToBoxAdapter(child: _FreeScansBanner()),
            ),
          const SliverToBoxAdapter(child: SectionHeader('What to eat next')),
          const SliverToBoxAdapter(child: SuggestionCarousel()),
          SliverToBoxAdapter(
            child: SectionHeader(
              "Today's meals",
              action: meals.isEmpty ? null : 'See diary',
              onAction: () => context.go(Routes.diary),
            ),
          ),
          if (meals.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.photo_camera_rounded,
                title: 'No meals yet today',
                message:
                    'Snap your breakfast, lunch or a snack — '
                    'we’ll do the counting.',
                actionLabel: 'Scan a meal',
                onAction: () => openScanner(context, ref),
              ),
            )
          else
            SliverPadding(
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
            ),
          SliverToBoxAdapter(child: SizedBox(height: bottomInset + Space.xxxl)),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final streak = ref.watch(streakProvider);
    final name = ref.watch(accountProvider)?.firstName ?? '';
    final unread = ref.watch(unreadNoticesProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.md,
        Space.gutter,
        Space.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${Fmt.greeting(now)} · ${Fmt.longDate(now)}'.toUpperCase(),
                  style: context.text.labelSmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Space.xxs),
                Semantics(
                  header: true,
                  child: Text(
                    // Greeting moves to the small label so the name
                    // always fits.
                    name.isEmpty ? 'Today' : 'Hi, $name',
                    style: context.text.headlineMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            label: '$streak day streak',
            excludeSemantics: true,
            child: Pill(
              icon: Icons.local_fire_department_rounded,
              label: '$streak',
              background: context.brand.accent,
              foreground: context.brand.onAccent,
            ),
          ),
          const SizedBox(width: Space.sm),
          const SizedBox(width: Space.xs),
          IconButton(
            onPressed: () => context.push(Routes.notifications),
            tooltip: unread > 0
                ? 'Notifications, $unread unread'
                : 'Notifications',
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_none_rounded),
            ),
            style: IconButton.styleFrom(
              backgroundColor: context.brand.card,
              side: BorderSide(color: context.colors.outlineVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekStrip extends ConsumerWidget {
  const _WeekStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = dateOnly(DateTime.now());
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final goal = ref.watch(targetsProvider).kcal;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.md),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: _DayDot(
                day: monday.add(Duration(days: i)),
                isToday: monday.add(Duration(days: i)) == today,
                isFuture: monday.add(Duration(days: i)).isAfter(today),
                progress:
                    ref
                        .watch(dayMacrosProvider(monday.add(Duration(days: i))))
                        .kcal /
                    goal,
                onTap: () {
                  ref
                      .read(selectedDayProvider.notifier)
                      .select(monday.add(Duration(days: i)));
                  context.go(Routes.diary);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.day,
    required this.isToday,
    required this.isFuture,
    required this.progress,
    required this.onTap,
  });

  final DateTime day;
  final bool isToday;
  final bool isFuture;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: !isFuture,
      label: '${Fmt.longDate(day)}${isToday ? ', today' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: isFuture ? null : onTap,
        borderRadius: Radii.lgAll,
        child: AnimatedContainer(
          duration: Motion.base,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: Space.sm),
          decoration: BoxDecoration(
            color: isToday ? c.onSurface : Colors.transparent,
            borderRadius: Radii.lgAll,
          ),
          child: Column(
            children: [
              Text(
                Fmt.weekdayShort(day).substring(0, 1),
                style: context.text.labelSmall?.copyWith(
                  color: isToday
                      ? c.surface.withValues(alpha: 0.7)
                      : c.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Space.xs + 2),
              ProgressRing(
                progress: isFuture ? 0 : progress,
                size: 32,
                stroke: 3,
                color: isToday ? context.brand.accent : c.onSurface,
                trackColor: isToday ? c.surface.withValues(alpha: 0.2) : null,
                child: Text(
                  '${day.day}',
                  style: context.text.labelMedium?.copyWith(
                    color: isToday
                        ? c.surface
                        : (isFuture ? c.outline : c.onSurface),
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

class _CaloriesCard extends ConsumerWidget {
  const _CaloriesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targets = ref.watch(targetsProvider);
    final eaten = ref.watch(dayMacrosProvider(dateOnly(DateTime.now())));
    final left = targets.kcal - eaten.kcal;
    final over = left < 0;

    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label: over
                      ? '${Fmt.kcal(-left)} calories over your goal'
                      : '${Fmt.kcal(left)} calories left of ${Fmt.kcal(targets.kcal)}',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        over ? 'Over goal' : 'Calories left',
                        style: context.text.labelMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: Space.xs),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          Fmt.kcal(left.abs()),
                          style: context.text.headlineLarge?.copyWith(
                            fontSize: 48,
                            color: over ? context.colors.error : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.sm),
                      Wrap(
                        spacing: Space.lg,
                        runSpacing: Space.xs,
                        children: [
                          _Stat(label: 'Eaten', value: Fmt.kcal(eaten.kcal)),
                          _Stat(label: 'Goal', value: Fmt.kcal(targets.kcal)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: Space.lg),
              ProgressRing(
                progress: eaten.kcal / targets.kcal,
                size: 112,
                stroke: 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      color: context.colors.onSurface,
                      size: 22,
                    ),
                    Text(
                      '${(eaten.kcal / targets.kcal * 100).round()}%',
                      style: context.text.labelLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.xl),
          const Divider(),
          const SizedBox(height: Space.lg),
          Row(
            children: [
              for (final k in MacroKind.values) ...[
                if (k != MacroKind.protein) const SizedBox(width: Space.lg),
                Expanded(
                  child: MacroBar(
                    kind: k,
                    value: k.of(eaten),
                    target: k.of(targets.macros),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: '$label ',
        style: context.text.bodySmall?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
        children: [TextSpan(text: value, style: context.text.titleSmall)],
      ),
    );
  }
}

class _FreeScansBanner extends ConsumerWidget {
  const _FreeScansBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final left = ref.watch(freeScansProvider);
    final ink = context.isDark
        ? context.colors.surfaceContainerHighest
        : const Color(0xFF14140F);
    return Material(
      color: ink,
      borderRadius: Radii.xlAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.paywall),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.lg,
            Space.md,
            Space.md,
            Space.md,
          ),
          child: Row(
            children: [
              Icon(Icons.bolt_rounded, color: context.brand.accent),
              const SizedBox(width: Space.md),
              Expanded(
                child: Text(
                  left == 0
                      ? 'You’ve used your free scans'
                      : '$left of ${FreeScansNotifier.allowance} free scans left',
                  style: context.text.titleSmall?.copyWith(color: Colors.white),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: context.brand.accent,
                  borderRadius: Radii.pillAll,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.lg,
                    vertical: Space.sm,
                  ),
                  child: Text(
                    'Go Pro',
                    style: context.text.labelMedium?.copyWith(
                      color: context.brand.onAccent,
                    ),
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
