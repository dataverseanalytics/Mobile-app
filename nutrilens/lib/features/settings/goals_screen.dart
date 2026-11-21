import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/format.dart';
import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/macro_widgets.dart';
import '../../core/widgets/settings_widgets.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../onboarding/onboarding_widgets.dart';

/// Daily targets: automatic (from the plan) or set by hand.
class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  late bool _custom = ref.read(customTargetsProvider) != null;
  late DailyTargets _draft = ref.read(targetsProvider);

  void _save() {
    ref.read(customTargetsProvider.notifier).set(_custom ? _draft : null);
    context.pop();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Daily targets saved')));
  }

  void _setMacro(MacroKind k, double v) {
    final m = _draft.macros;
    final macros = switch (k) {
      MacroKind.protein => Macros(protein: v, carbs: m.carbs, fat: m.fat),
      MacroKind.carbs => Macros(protein: m.protein, carbs: v, fat: m.fat),
      MacroKind.fat => Macros(protein: m.protein, carbs: m.carbs, fat: v),
    };
    setState(() => _draft = DailyTargets(kcal: macros.kcal, macros: macros));
  }

  @override
  Widget build(BuildContext context) {
    final auto = ref.watch(autoTargetsProvider);
    final shown = _custom ? _draft : auto;

    return SettingsPage(
      title: 'Daily targets',
      bottom: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.sm,
            Space.gutter,
            Space.md,
          ),
          child: FilledButton(onPressed: _save, child: const Text('Save')),
        ),
      ),
      children: [
        Segmented<bool>(
          options: const [false, true],
          value: _custom,
          labelOf: (v) => v ? 'Custom' : 'Automatic',
          onChanged: (v) => setState(() {
            _custom = v;
            if (v) _draft = auto;
          }),
        ),
        const SizedBox(height: Space.lg),
        AppCard(
          child: Column(
            children: [
              Text(
                'Calories per day',
                style: context.text.labelMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Space.xs),
              Text(Fmt.kcal(shown.kcal), style: context.text.headlineLarge),
              const SizedBox(height: Space.md),
              Text(
                _custom
                    ? 'Calories update as you change your macros.'
                    : 'Calculated from your body, activity and goal.',
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.md),
        if (_custom)
          for (final k in MacroKind.values) ...[
            ValuePicker(
              label: '${k.label} (g)',
              value: k.of(_draft.macros).roundToDouble().clamp(0, 500),
              unit: 'g',
              min: 0,
              max: 500,
              step: 5,
              onChanged: (v) => _setMacro(k, v),
            ),
            const SizedBox(height: Space.md),
          ]
        else ...[
          SettingsGroup(
            children: [
              for (final k in MacroKind.values)
                SettingsRow(
                  dot: k.color(context),
                  title: k.label,
                  value: Fmt.grams(k.of(auto.macros)),
                ),
            ],
          ),
          const SizedBox(height: Space.md),
          OutlinedButton.icon(
            onPressed: () => context.push(Routes.onboarding),
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Update my body & goal'),
          ),
        ],
      ],
    );
  }
}
