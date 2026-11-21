import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/macro_widgets.dart';
import '../../data/models.dart';

sealed class EditResult {
  const EditResult();
}

final class EditServings extends EditResult {
  const EditServings(this.servings);
  final double servings;
}

final class EditRemove extends EditResult {
  const EditRemove();
}

/// Adjust a recognised item's portion with live nutrition.
/// With [adding] true it becomes the "add food" sheet (no Remove button).
Future<EditResult?> showEditItemSheet(
  BuildContext context,
  FoodItem item, {
  bool adding = false,
}) {
  return showModalBottomSheet<EditResult>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => _EditItemSheet(item: item, adding: adding),
  );
}

class _EditItemSheet extends StatefulWidget {
  const _EditItemSheet({required this.item, required this.adding});
  final FoodItem item;
  final bool adding;

  @override
  State<_EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends State<_EditItemSheet> {
  late double _servings = widget.item.servings;
  static const _quick = [0.5, 1.0, 1.5, 2.0];

  void _set(double v) {
    HapticFeedback.selectionClick();
    setState(() => _servings = v.clamp(0.25, 10));
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item.copyWith(servings: _servings);
    final m = item.total;
    return Padding(
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
          Text(item.name, style: context.text.headlineSmall),
          const SizedBox(height: Space.xxs),
          Text(
            'Portion: ${item.unit}',
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Space.xxl),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: _servings > 0.25
                    ? () => _set(_servings - 0.25)
                    : null,
                tooltip: 'Less',
                icon: const Icon(Icons.remove_rounded),
                style: IconButton.styleFrom(fixedSize: const Size.square(56)),
              ),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  label:
                      '${Fmt.servings(_servings)} servings, ${Fmt.kcal(m.kcal)} calories',
                  excludeSemantics: true,
                  child: Column(
                    children: [
                      Text(
                        '${Fmt.servings(_servings)}×',
                        style: context.text.headlineLarge?.copyWith(
                          fontSize: 44,
                        ),
                      ),
                      Text(
                        '${Fmt.kcal(m.kcal)} kcal',
                        style: context.text.titleSmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => _set(_servings + 0.25),
                tooltip: 'More',
                icon: const Icon(Icons.add_rounded),
                style: IconButton.styleFrom(fixedSize: const Size.square(56)),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          Row(
            children: [
              for (final q in _quick) ...[
                if (q != _quick.first) const SizedBox(width: Space.sm),
                Expanded(
                  child: ChoiceChip(
                    label: SizedBox(
                      width: double.infinity,
                      child: Text(
                        '${Fmt.servings(q)}×',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    selected: _servings == q,
                    onSelected: (_) => _set(q),
                    labelStyle: context.text.labelMedium?.copyWith(
                      color: _servings == q
                          ? context.colors.surface
                          : context.colors.onSurface,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: Space.xl),
          Row(
            children: [
              for (final k in MacroKind.values) ...[
                if (k != MacroKind.protein) const SizedBox(width: Space.sm),
                Expanded(
                  child: MacroTile(kind: k, grams: k.of(m)),
                ),
              ],
            ],
          ),
          const SizedBox(height: Space.xxl),
          Row(
            children: [
              if (!widget.adding)
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, const EditRemove()),
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.error,
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Remove'),
                ),
              if (!widget.adding) const Spacer(),
              Expanded(
                flex: widget.adding ? 1 : 0,
                child: FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, EditServings(_servings)),
                  child: Text(
                    widget.adding
                        ? 'Add · ${Fmt.kcal(m.kcal)} kcal'
                        : 'Save portion',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
