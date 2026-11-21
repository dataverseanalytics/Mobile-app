import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';

/// Title + supporting line at the top of each onboarding step.
class StepHeading extends StatelessWidget {
  const StepHeading({super.key, required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: context.text.displaySmall),
        ),
        const SizedBox(height: Space.sm),
        Text(
          subtitle,
          style: context.text.bodyLarge?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Large selectable option row.
class OptionCard extends StatelessWidget {
  const OptionCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Pressable(
        onTap: onTap,
        semanticLabel: subtitle == null ? title : '$title. $subtitle',
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.enter,
          padding: const EdgeInsets.symmetric(
            horizontal: Space.lg,
            vertical: Space.lg,
          ),
          decoration: BoxDecoration(
            color: selected ? c.onSurface : context.brand.card,
            borderRadius: Radii.xlAll,
            border: Border.all(
              color: selected ? c.onSurface : c.outlineVariant,
              width: 1.5,
            ),
          ),
          child: ExcludeSemantics(
            child: Row(
              children: [
                if (icon != null) ...[
                  AnimatedContainer(
                    duration: Motion.fast,
                    padding: const EdgeInsets.all(Space.md),
                    decoration: BoxDecoration(
                      color: selected
                          ? context.brand.accent
                          : c.surfaceContainerHigh,
                      borderRadius: Radii.mdAll,
                    ),
                    child: Icon(
                      icon,
                      size: 22,
                      color: selected ? context.brand.onAccent : c.onSurface,
                    ),
                  ),
                  const SizedBox(width: Space.lg),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.text.titleMedium?.copyWith(
                          color: selected ? c.surface : c.onSurface,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: Space.xxs),
                        Text(
                          subtitle!,
                          style: context.text.bodyMedium?.copyWith(
                            color: selected
                                ? c.surface.withValues(alpha: 0.7)
                                : c.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: Motion.fast,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.brand.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(Space.xs),
                      child: Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: context.brand.onAccent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Big centred value with − / + buttons and a slider underneath.
class ValuePicker extends StatelessWidget {
  const ValuePicker({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
    this.decimals = 0,
  });

  final String label;
  final double value;
  final String unit;
  final double min;
  final double max;
  final double step;
  final int decimals;
  final ValueChanged<double> onChanged;

  void _nudge(double d) {
    HapticFeedback.selectionClick();
    onChanged((value + d).clamp(min, max));
  }

  @override
  Widget build(BuildContext context) {
    final text = value.toStringAsFixed(decimals);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.brand.card,
        borderRadius: Radii.xlAll,
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.lg,
          Space.lg,
          Space.lg,
          Space.sm,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: context.text.labelMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Space.sm),
            Row(
              children: [
                _RoundButton(
                  icon: Icons.remove_rounded,
                  tooltip: 'Decrease $label',
                  onTap: value > min ? () => _nudge(-step) : null,
                ),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    label: '$label $text $unit',
                    excludeSemantics: true,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          text,
                          style: context.text.headlineLarge?.copyWith(
                            fontSize: 44,
                          ),
                        ),
                        const SizedBox(width: Space.xs),
                        Text(
                          unit,
                          style: context.text.titleMedium?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _RoundButton(
                  icon: Icons.add_rounded,
                  tooltip: 'Increase $label',
                  onTap: value < max ? () => _nudge(step) : null,
                ),
              ],
            ),
            Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: ((max - min) / step).round(),
              label: '$text $unit',
              semanticFormatterCallback: (v) =>
                  '${v.toStringAsFixed(decimals)} $unit',
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: context.colors.surfaceContainerHigh,
        foregroundColor: context.colors.onSurface,
        fixedSize: const Size.square(Sizes.minTap),
      ),
    );
  }
}

/// Two-option segmented toggle (e.g. Female / Male).
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.value,
    required this.labelOf,
    required this.onChanged,
  });

  final List<T> options;
  final T value;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceContainerHigh,
        borderRadius: Radii.pillAll,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.xs),
        child: Row(
          children: [
            for (final o in options)
              Expanded(
                child: Semantics(
                  selected: o == value,
                  button: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onChanged(o);
                    },
                    child: AnimatedContainer(
                      duration: Motion.fast,
                      curve: Motion.enter,
                      height: Sizes.minTap,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: o == value
                            ? context.brand.card
                            : Colors.transparent,
                        borderRadius: Radii.pillAll,
                        boxShadow: o == value
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        labelOf(o),
                        style: context.text.labelLarge?.copyWith(
                          color: o == value ? c.onSurface : c.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
