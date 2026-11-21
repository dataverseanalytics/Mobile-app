import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/format.dart';
import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/food_photo.dart';
import '../../core/widgets/macro_widgets.dart';
import '../../data/ai_repository.dart';
import '../../data/api/api_client.dart';
import '../../data/models.dart';
import '../../data/scan_repository.dart';
import '../../state/providers.dart';
import '../scan/edit_item_sheet.dart';

/// Food search (server when connected, bundled list offline).
final foodSearchProvider = FutureProvider.autoDispose
    .family<List<FoodEntry>, String>(
      (ref, query) => ref.watch(scanRepositoryProvider).search(query),
    );

/// Manual search — the backup when a photo isn't practical.
/// `?addTo=draft` adds the food to the scan being reviewed instead of
/// logging a new meal.
class FoodSearchScreen extends ConsumerStatefulWidget {
  const FoodSearchScreen({super.key});

  @override
  ConsumerState<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends ConsumerState<FoodSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  /// What's typed (instant UI) vs. what's searched (debounced, no request
  /// per keystroke).
  String _query = '';
  String _searched = '';
  bool _describing = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    setState(() => _query = v);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _searched = v.trim());
    });
  }

  bool get _addToDraft =>
      GoRouterState.of(context).uri.queryParameters['addTo'] == 'draft';

  Future<void> _pick(FoodEntry food) async {
    final item = FoodItem(
      id: 'f-${DateTime.now().microsecondsSinceEpoch}',
      name: food.name,
      unit: food.unit,
      macros: food.macros,
    );
    final result = await showEditItemSheet(context, item, adding: true);
    if (result is! EditServings || !mounted) return;
    final chosen = item.copyWith(servings: result.servings);
    unawaited(HapticFeedback.mediumImpact());
    if (!mounted) return;

    if (_addToDraft) {
      ref.read(scanDraftProvider.notifier).addItem(chosen);
      context.pop();
      return;
    }
    final now = DateTime.now();
    ref
        .read(diaryProvider.notifier)
        .add(
          Meal(
            id: 'meal-${now.microsecondsSinceEpoch}',
            name: food.name,
            photo: food.photo,
            loggedAt: now,
            type: MealType.forTime(now),
            items: [chosen],
          ),
        );
    final messenger = ScaffoldMessenger.of(context);
    context.go(Routes.today);
    messenger.showSnackBar(
      SnackBar(
        content: Text('${food.name} logged · ${Fmt.kcal(chosen.kcal)} kcal'),
      ),
    );
  }

  /// Free text ("2 rotis and dal") → AI → the normal review screen.
  Future<void> _describe() async {
    final text = _query.trim();
    if (text.length < 2 || _describing) return;
    FocusScope.of(context).unfocus();
    setState(() => _describing = true);
    try {
      final meal = await ref.read(aiRepositoryProvider).describeMeal(text);
      if (!mounted) return;
      ref.read(scanDraftProvider.notifier).set(meal);
      context.pushReplacement(Routes.result);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _describing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is AiFailure
                ? e.message
                : "Couldn't reach the AI. Check your connection and try again.",
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(foodSearchProvider(_searched));
    final showSuggestions = _searched.isEmpty;
    final list = search.value ?? const <FoodEntry>[];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text(_addToDraft ? 'Add an item' : 'Search food'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.xs,
              Space.gutter,
              Space.md,
            ),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: (_) {
                if (!_addToDraft && list.isEmpty) _describe();
              },
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                hintText: _addToDraft
                    ? 'Try “dal”, “dosa” or “egg”'
                    : 'Search, or describe your meal',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _controller.clear();
                          _debounce?.cancel();
                          setState(() => _query = _searched = '');
                        },
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.cancel_rounded),
                      ),
              ),
            ),
          ),
          if (!_addToDraft && _query.trim().length >= 2)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                0,
                Space.gutter,
                Space.md,
              ),
              child: _DescribeTile(
                text: _query.trim(),
                busy: _describing,
                onTap: _describe,
              ),
            ),
          SizedBox(
            height: 2,
            child: search.isLoading ? const LinearProgressIndicator() : null,
          ),
          Expanded(
            child: search.hasError && list.isEmpty
                ? SingleChildScrollView(
                    child: EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: "Search isn't available right now",
                      message: switch (search.error) {
                        ScanFailure(:final message) => message,
                        ApiException(:final message) => message,
                        _ => 'Check your connection and try again.',
                      },
                      actionLabel: 'Try again',
                      onAction: () =>
                          ref.invalidate(foodSearchProvider(_searched)),
                    ),
                  )
                : !showSuggestions && !search.isLoading && list.isEmpty
                ? SingleChildScrollView(
                    child: EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No match for “${_query.trim()}”',
                      message: _addToDraft
                          ? 'Check the spelling, or try a simpler name.'
                          : 'Tap “Log with AI” above — it understands whole meals like “2 rotis, dal and salad”.',
                      actionLabel: 'Snap a photo instead',
                      onAction: () => context.pushReplacement(Routes.scan),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      Space.gutter,
                      0,
                      Space.gutter,
                      MediaQuery.paddingOf(context).bottom + Space.xl,
                    ),
                    itemCount: list.length + 1,
                    separatorBuilder: (_, i) => i == 0
                        ? const SizedBox.shrink()
                        : Divider(
                            indent: 64,
                            color: context.colors.outlineVariant,
                          ),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(
                            top: Space.sm,
                            bottom: Space.sm,
                          ),
                          child: Text(
                            showSuggestions
                                ? 'Popular'
                                : '${list.length} results',
                            style: context.text.labelMedium?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        );
                      }
                      final f = list[i - 1];
                      return _FoodRow(
                        key: ValueKey(f.name),
                        food: f,
                        onTap: () => _pick(f),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({super.key, required this.food, required this.onTap});
  final FoodEntry food;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: Radii.mdAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        child: Row(
          children: [
            if (food.photo != null)
              FoodPhoto(food.photo, width: 48, height: 48, radius: Radii.mdAll)
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  color: context.colors.surfaceContainerHigh,
                  borderRadius: Radii.mdAll,
                ),
                child: SizedBox.square(
                  dimension: 48,
                  child: Icon(
                    Icons.restaurant_rounded,
                    color: context.colors.onSurfaceVariant,
                    size: 20,
                  ),
                ),
              ),
            const SizedBox(width: Space.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(food.name, style: context.text.titleSmall),
                  const SizedBox(height: Space.xxs),
                  Text(
                    food.aiEstimated ? '${food.unit} · AI estimate' : food.unit,
                    style: context.text.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Space.xs),
                  Wrap(
                    spacing: Space.md,
                    children: [
                      MacroDot(
                        kind: MacroKind.protein,
                        grams: food.macros.protein,
                      ),
                      MacroDot(kind: MacroKind.carbs, grams: food.macros.carbs),
                      MacroDot(kind: MacroKind.fat, grams: food.macros.fat),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.md),
            Text(
              '${Fmt.kcal(food.macros.kcal)} kcal',
              style: context.text.labelLarge,
            ),
            const SizedBox(width: Space.sm),
            Icon(Icons.add_circle_rounded, color: context.colors.onSurface),
          ],
        ),
      ),
    );
  }
}

/// "Log 'two rotis and dal' with AI" — shown above results while typing.
class _DescribeTile extends StatelessWidget {
  const _DescribeTile({
    required this.text,
    required this.busy,
    required this.onTap,
  });

  final String text;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.brand.accent.withValues(alpha: 0.14),
      borderRadius: Radii.lgAll,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: Radii.lgAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.lg,
            vertical: Space.md,
          ),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 24,
                child: busy
                    ? const CircularProgressIndicator(strokeWidth: 2.4)
                    : Icon(
                        Icons.auto_awesome_rounded,
                        color: context.colors.onSurface,
                      ),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      busy ? 'Working it out…' : 'Log with AI',
                      style: context.text.titleSmall,
                    ),
                    const SizedBox(height: Space.xxs),
                    Text(
                      '“$text”',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: context.colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
