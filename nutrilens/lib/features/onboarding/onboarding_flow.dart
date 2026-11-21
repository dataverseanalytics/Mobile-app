import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/assets.dart';
import '../../core/format.dart';
import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/calorie_ring.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/food_photo.dart';
import '../../core/widgets/macro_widgets.dart';
import '../../data/models.dart';
import '../../data/nutrition.dart';
import '../../state/providers.dart';
import 'onboarding_widgets.dart';

enum _Step { goal, about, body, target, activity, building, ready }

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final _pages = PageController();
  int _index = 0;

  List<_Step> _steps(Goal goal) => [
    _Step.goal,
    _Step.about,
    _Step.body,
    if (goal != Goal.maintain) _Step.target,
    _Step.activity,
    _Step.building,
    _Step.ready,
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int i) {
    setState(() => _index = i);
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _pages.jumpToPage(i);
    } else {
      _pages.animateToPage(i, duration: Motion.slow, curve: Motion.emphasized);
    }
  }

  /// New users have nowhere to go back to; people re-running the plan
  /// from Settings return to where they came from.
  bool get _canLeave => ref.read(accountProvider)?.onboarded ?? false;

  void _back() {
    if (_index > 0) {
      _go(_index - 1);
    } else if (_canLeave) {
      context.canPop() ? context.pop() : context.go(Routes.profile);
    }
  }

  Future<void> _finish() async {
    final recalculating = _canLeave;
    await ref.read(accountProvider.notifier).completeOnboarding();
    if (!mounted) return;
    if (recalculating) {
      context.go(Routes.profile);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your plan has been updated')),
      );
    } else {
      context.go('${Routes.paywall}?from=onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    final goal = ref.watch(profileProvider.select((p) => p.goal));
    final steps = _steps(goal);
    final step = steps[_index.clamp(0, steps.length - 1)];
    final inputSteps = steps.length - 2; // building + ready aren't questions
    final showChrome = step != _Step.building;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && step != _Step.building) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Placeholders keep the Column's children stable so the
              // PageView keeps its state when the chrome hides.
              if (showChrome && step != _Step.ready)
                _TopBar(
                  index: _index,
                  total: inputSteps,
                  onBack: _index > 0 || _canLeave ? _back : null,
                )
              else
                const SizedBox.shrink(),
              Expanded(
                key: const ValueKey('onboarding-pages'),
                child: PageView(
                  controller: _pages,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final s in steps)
                      switch (s) {
                        _Step.goal => const _GoalStep(),
                        _Step.about => const _AboutStep(),
                        _Step.body => const _BodyStep(),
                        _Step.target => const _TargetStep(),
                        _Step.activity => const _ActivityStep(),
                        _Step.building => _BuildingStep(
                          active: step == _Step.building,
                          onDone: () => _go(_index + 1),
                        ),
                        _Step.ready => const _ReadyStep(),
                      },
                  ],
                ),
              ),
              if (showChrome)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.gutter,
                    Space.sm,
                    Space.gutter,
                    Space.lg,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: step == _Step.ready
                          ? _finish
                          : () => _go(_index + 1),
                      child: Text(
                        step == _Step.ready ? 'Start my plan' : 'Continue',
                      ),
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.index,
    required this.total,
    required this.onBack,
  });
  final int index;
  final int total;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.sm, Space.xs, Space.gutter, 0),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_rounded),
            )
          else
            const SizedBox(width: Space.md),
          const SizedBox(width: Space.xs),
          Expanded(
            child: Semantics(
              label: 'Step ${index + 1} of $total',
              excludeSemantics: true,
              child: Row(
                children: [
                  for (var i = 0; i < total; i++) ...[
                    if (i > 0) const SizedBox(width: Space.xs),
                    Expanded(
                      child: AnimatedContainer(
                        duration: Motion.base,
                        height: 5,
                        decoration: BoxDecoration(
                          color: i <= index
                              ? context.colors.onSurface
                              : context.brand.ringTrack,
                          borderRadius: Radii.pillAll,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: Space.md),
          Text(
            '${index + 1}/$total',
            style: context.text.labelMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Scrollable padded body shared by every question step.
class _StepBody extends StatelessWidget {
  const _StepBody({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.xxl,
        Space.gutter,
        Space.xxl,
      ),
      children: children,
    );
  }
}

class _GoalStep extends ConsumerWidget {
  const _GoalStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(profileProvider.select((p) => p.goal));
    const icons = {
      Goal.lose: Icons.trending_down_rounded,
      Goal.maintain: Icons.balance_rounded,
      Goal.gain: Icons.fitness_center_rounded,
    };
    return _StepBody(
      children: [
        const StepHeading(
          title: "What's your goal?",
          subtitle: "We'll tailor your daily calories and macros to it.",
        ),
        const SizedBox(height: Space.xxxl),
        for (final g in Goal.values) ...[
          OptionCard(
            title: g.label,
            subtitle: g.subtitle,
            icon: icons[g],
            selected: g == goal,
            onTap: () => ref
                .read(profileProvider.notifier)
                .update((p) => p.copyWith(goal: g)),
          ),
          const SizedBox(height: Space.md),
        ],
      ],
    );
  }
}

class _AboutStep extends ConsumerWidget {
  const _AboutStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider);
    final n = ref.read(profileProvider.notifier);
    return _StepBody(
      children: [
        const StepHeading(
          title: 'A little about you',
          subtitle: 'Used only to estimate how much energy your body needs.',
        ),
        const SizedBox(height: Space.xxxl),
        Text('Sex', style: context.text.labelLarge),
        const SizedBox(height: Space.sm),
        Segmented<Sex>(
          options: Sex.values,
          value: p.sex,
          labelOf: (s) => s == Sex.female ? 'Female' : 'Male',
          onChanged: (s) => n.update((p) => p.copyWith(sex: s)),
        ),
        const SizedBox(height: Space.xxl),
        ValuePicker(
          label: 'Age',
          value: p.age.toDouble(),
          unit: 'years',
          min: 14,
          max: 90,
          onChanged: (v) => n.update((p) => p.copyWith(age: v.round())),
        ),
      ],
    );
  }
}

class _BodyStep extends ConsumerWidget {
  const _BodyStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider);
    final n = ref.read(profileProvider.notifier);
    return _StepBody(
      children: [
        const StepHeading(
          title: 'Height & weight',
          subtitle: 'You can change these any time in your profile.',
        ),
        const SizedBox(height: Space.xxxl),
        ValuePicker(
          label: 'Height',
          value: p.heightCm,
          unit: 'cm',
          min: 130,
          max: 220,
          onChanged: (v) => n.update((p) => p.copyWith(heightCm: v)),
        ),
        const SizedBox(height: Space.md),
        ValuePicker(
          label: 'Current weight',
          value: p.weightKg,
          unit: 'kg',
          min: 35,
          max: 200,
          step: 0.5,
          decimals: 1,
          onChanged: (v) => n.update(
            (p) => p.copyWith(
              weightKg: v,
              targetWeightKg: p.goal == Goal.lose
                  ? (p.targetWeightKg < v ? p.targetWeightKg : v - 5)
                  : (p.targetWeightKg > v ? p.targetWeightKg : v + 4),
            ),
          ),
        ),
      ],
    );
  }
}

class _TargetStep extends ConsumerWidget {
  const _TargetStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider);
    final n = ref.read(profileProvider.notifier);
    final losing = p.goal == Goal.lose;
    final min = losing ? 35.0 : p.weightKg;
    final max = losing ? p.weightKg : 200.0;
    final weeks = Nutrition.weeksToGoal(p);
    final date = DateTime.now().add(Duration(days: weeks * 7));
    const paces = [0.25, 0.5, 0.75, 1.0];
    return _StepBody(
      children: [
        StepHeading(
          title: losing ? 'Your target weight' : 'Where do you want to be?',
          subtitle: 'Steady and sustainable beats fast and frustrating.',
        ),
        const SizedBox(height: Space.xxxl),
        ValuePicker(
          label: 'Target weight',
          value: p.targetWeightKg.clamp(min, max),
          unit: 'kg',
          min: min,
          max: max,
          step: 0.5,
          decimals: 1,
          onChanged: (v) => n.update((p) => p.copyWith(targetWeightKg: v)),
        ),
        const SizedBox(height: Space.xxl),
        Text('Weekly pace', style: context.text.labelLarge),
        const SizedBox(height: Space.sm),
        Row(
          children: [
            for (final pace in paces) ...[
              if (pace != paces.first) const SizedBox(width: Space.sm),
              Expanded(
                child: ChoiceChip(
                  label: SizedBox(
                    width: double.infinity,
                    child: Text('$pace kg', textAlign: TextAlign.center),
                  ),
                  selected: p.paceKgPerWeek == pace,
                  onSelected: (_) =>
                      n.update((p) => p.copyWith(paceKgPerWeek: pace)),
                  labelStyle: context.text.labelMedium?.copyWith(
                    color: p.paceKgPerWeek == pace
                        ? context.colors.surface
                        : context.colors.onSurface,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: Space.sm),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: Space.xl),
        if (weeks > 0)
          AppCard(
            padding: const EdgeInsets.all(Space.lg),
            child: Row(
              children: [
                Icon(Icons.flag_rounded, color: context.brand.success),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: 'You could reach ',
                      children: [
                        TextSpan(
                          text: '${p.targetWeightKg.toStringAsFixed(1)} kg',
                          style: context.text.titleSmall,
                        ),
                        const TextSpan(text: ' by '),
                        TextSpan(
                          text: '${Fmt.dayMonth(date)} ${date.year}',
                          style: context.text.titleSmall,
                        ),
                      ],
                    ),
                    style: context.text.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ActivityStep extends ConsumerWidget {
  const _ActivityStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(profileProvider.select((p) => p.activity));
    const icons = {
      Activity.sedentary: Icons.chair_rounded,
      Activity.light: Icons.directions_walk_rounded,
      Activity.moderate: Icons.directions_run_rounded,
      Activity.high: Icons.local_fire_department_rounded,
    };
    return _StepBody(
      children: [
        const StepHeading(
          title: 'How active are you?',
          subtitle: 'Think about a typical week, not your best one.',
        ),
        const SizedBox(height: Space.xxxl),
        for (final v in Activity.values) ...[
          OptionCard(
            title: v.label,
            subtitle: v.subtitle,
            icon: icons[v],
            selected: v == a,
            onTap: () => ref
                .read(profileProvider.notifier)
                .update((p) => p.copyWith(activity: v)),
          ),
          const SizedBox(height: Space.md),
        ],
      ],
    );
  }
}

/// A short, honest "calculating" moment that builds anticipation.
class _BuildingStep extends StatefulWidget {
  const _BuildingStep({required this.active, required this.onDone});
  final bool active;
  final VoidCallback onDone;

  @override
  State<_BuildingStep> createState() => _BuildingStepState();
}

class _BuildingStepState extends State<_BuildingStep> {
  static const _lines = [
    'Calculating your metabolism',
    'Balancing protein, carbs & fat',
    'Setting your daily target',
  ];
  double _progress = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // PageView builds pages lazily, so this step is usually created
    // already active.
    if (widget.active) _start();
  }

  @override
  void didUpdateWidget(_BuildingStep old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _start();
  }

  void _start() {
    _progress = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 40), (t) {
      if (!mounted) return t.cancel();
      setState(() => _progress = (_progress + 0.018).clamp(0, 1));
      if (_progress >= 1) {
        t.cancel();
        Future<void>.delayed(const Duration(milliseconds: 350), () {
          if (mounted) widget.onDone();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Space.gutter),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ProgressRing(
            progress: _progress,
            size: 168,
            color: context.colors.onSurface,
            child: Text(
              '${(_progress * 100).round()}%',
              style: context.text.headlineLarge,
            ),
          ),
          const SizedBox(height: Space.xxxl),
          Text(
            'Building your plan',
            style: context.text.displaySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Space.xxl),
          for (var i = 0; i < _lines.length; i++)
            _CheckLine(
              text: _lines[i],
              done: _progress > (i + 1) / (_lines.length + 0.5),
            ),
        ],
      ),
    );
  }
}

class _CheckLine extends StatelessWidget {
  const _CheckLine({required this.text, required this.done});
  final String text;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs + 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: Motion.base,
            child: done
                ? Icon(
                    Icons.check_circle_rounded,
                    key: const ValueKey(true),
                    color: context.brand.success,
                    size: 22,
                  )
                : Icon(
                    Icons.radio_button_unchecked_rounded,
                    key: const ValueKey(false),
                    color: context.colors.outline,
                    size: 22,
                  ),
          ),
          const SizedBox(width: Space.md),
          Flexible(
            child: Text(
              text,
              style: context.text.bodyLarge?.copyWith(
                color: done
                    ? context.colors.onSurface
                    : context.colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadyStep extends ConsumerWidget {
  const _ReadyStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider);
    final t = ref.watch(targetsProvider);
    final weeks = Nutrition.weeksToGoal(p);
    final date = DateTime.now().add(Duration(days: weeks * 7));
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.xxxl,
        Space.gutter,
        Space.xxl,
      ),
      children: [
        Center(
          child: Pill(
            label: 'Personalised for you',
            icon: Icons.auto_awesome_rounded,
            background: context.brand.accent,
            foreground: context.brand.onAccent,
          ),
        ),
        const SizedBox(height: Space.lg),
        Text(
          'Your plan is ready',
          style: context.text.displayMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Space.xxl),
        AppCard(
          child: Column(
            children: [
              ProgressRing(
                progress: 1,
                size: 176,
                stroke: 16,
                color: context.brand.accent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(Fmt.kcal(t.kcal), style: context.text.headlineLarge),
                    Text(
                      'kcal / day',
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.xxl),
              Row(
                children: [
                  for (final k in MacroKind.values) ...[
                    if (k != MacroKind.protein) const SizedBox(width: Space.sm),
                    Expanded(
                      child: MacroTile(kind: k, grams: k.of(t.macros)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.md),
        if (weeks > 0)
          AppCard(
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                const FoodPhoto(
                  Photos.workout,
                  width: 96,
                  height: 96,
                  radius: BorderRadius.horizontal(
                    left: Radius.circular(Radii.xl),
                  ),
                ),
                const SizedBox(width: Space.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Goal date',
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${p.targetWeightKg.toStringAsFixed(1)} kg by ${Fmt.dayMonth(date)}',
                        style: context.text.titleMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.lg),
              ],
            ),
          ),
      ],
    );
  }
}
