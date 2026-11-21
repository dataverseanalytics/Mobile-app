import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../theme/theme_x.dart';
import '../theme/tokens.dart';

enum MacroKind { protein, carbs, fat }

extension MacroKindX on MacroKind {
  String get label => switch (this) {
    MacroKind.protein => 'Protein',
    MacroKind.carbs => 'Carbs',
    MacroKind.fat => 'Fat',
  };
  String get short => switch (this) {
    MacroKind.protein => 'P',
    MacroKind.carbs => 'C',
    MacroKind.fat => 'F',
  };
  Color color(BuildContext context) => switch (this) {
    MacroKind.protein => context.brand.protein,
    MacroKind.carbs => context.brand.carbs,
    MacroKind.fat => context.brand.fat,
  };
  double of(Macros m) => switch (this) {
    MacroKind.protein => m.protein,
    MacroKind.carbs => m.carbs,
    MacroKind.fat => m.fat,
  };
}

/// Label, "82 / 140 g" and an animated bar.
class MacroBar extends StatelessWidget {
  const MacroBar({
    super.key,
    required this.kind,
    required this.value,
    required this.target,
  });

  final MacroKind kind;
  final double value;
  final double target;

  @override
  Widget build(BuildContext context) {
    final p = target <= 0 ? 0.0 : (value / target).clamp(0.0, 1.0);
    final color = kind.color(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: '${kind.label} ${value.round()} of ${target.round()} grams',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kind.label,
            style: context.text.labelMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Space.xs),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${value.round()}',
                  style: context.text.titleMedium,
                ),
                TextSpan(
                  text: ' / ${target.round()}g',
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: Space.sm),
          ClipRRect(
            borderRadius: Radii.pillAll,
            child: SizedBox(
              height: 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: context.brand.ringTrack),
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: p),
                    duration: reduce ? Duration.zero : Motion.ring,
                    curve: Motion.emphasized,
                    builder: (_, v, _) => FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: v,
                      child: ColoredBox(color: color),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact "● 38g" inline macro.
class MacroDot extends StatelessWidget {
  const MacroDot({super.key, required this.kind, required this.grams});
  final MacroKind kind;
  final double grams;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${kind.label} ${grams.round()} grams',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: kind.color(context),
              shape: BoxShape.circle,
            ),
            child: const SizedBox.square(dimension: 7),
          ),
          const SizedBox(width: Space.xs),
          Text(
            '${kind.short} ${grams.round()}g',
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Big tile: coloured icon chip, grams, label. Used on scan results.
class MacroTile extends StatelessWidget {
  const MacroTile({super.key, required this.kind, required this.grams});
  final MacroKind kind;
  final double grams;

  @override
  Widget build(BuildContext context) {
    final color = kind.color(context);
    return Semantics(
      label: '${kind.label} ${grams.round()} grams',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.brand.card,
          borderRadius: Radii.lgAll,
          border: Border.all(color: context.colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: Radii.smAll,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(_icon, size: 16, color: color),
                ),
              ),
              const SizedBox(height: Space.md),
              Text(
                '${grams.round()}g',
                style: context.text.titleLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                kind.label,
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData get _icon => switch (kind) {
    MacroKind.protein => Icons.egg_alt_rounded,
    MacroKind.carbs => Icons.grain_rounded,
    MacroKind.fat => Icons.water_drop_rounded,
  };
}
