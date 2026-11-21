import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/food_photo.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

enum _CardStyle {
  lime('Lime', Palette.lime, Palette.ink),
  ink('Ink', Palette.ink, Palette.white),
  paper('Paper', Palette.paper, Palette.ink);

  const _CardStyle(this.label, this.bg, this.fg);
  final String label;
  final Color bg;
  final Color fg;
}

/// A story-ready image of the meal — the app's viral loop.
class ShareCardScreen extends ConsumerStatefulWidget {
  const ShareCardScreen({super.key, required this.mealId});

  /// A diary meal id, or `draft` for the scan being reviewed.
  final String mealId;

  @override
  ConsumerState<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends ConsumerState<ShareCardScreen> {
  final _cardKey = GlobalKey();
  _CardStyle _style = _CardStyle.lime;
  bool _sharing = false;

  Future<void> _share(Meal meal) async {
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes.buffer.asUint8List(),
              mimeType: 'image/png',
              name: 'nutrilens-meal.png',
            ),
          ],
          text:
              '${meal.name} — ${Fmt.kcal(meal.kcal)} kcal. Scanned with NutriLens.',
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't open the share sheet. Please try again."),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meal = widget.mealId == 'draft'
        ? ref.watch(scanDraftProvider)
        : ref
              .watch(diaryProvider)
              .where((m) => m.id == widget.mealId)
              .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Share your plate'),
        leading: IconButton(
          onPressed: () => context.pop(),
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: meal == null
          ? const Center(
              child: EmptyState(
                icon: Icons.image_not_supported_outlined,
                title: 'Nothing to share',
                message: 'This meal is no longer available.',
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.huge,
                      vertical: Space.md,
                    ),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 9 / 14,
                        child: FittedBox(
                          child: RepaintBoundary(
                            key: _cardKey,
                            child: _ShareCard(meal: meal, style: _style),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final s in _CardStyle.values)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Space.sm,
                          ),
                          child: _StyleSwatch(
                            style: s,
                            selected: s == _style,
                            onTap: () => setState(() => _style = s),
                          ),
                        ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.gutter,
                      Space.lg,
                      Space.gutter,
                      Space.md,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _sharing ? null : () => _share(meal),
                        icon: const Icon(Icons.ios_share_rounded),
                        label: Text(
                          _sharing ? 'Preparing…' : 'Share to stories',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _StyleSwatch extends StatelessWidget {
  const _StyleSwatch({
    required this.style,
    required this.selected,
    required this.onTap,
  });
  final _CardStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: '${style.label} style',
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: Column(
          children: [
            AnimatedContainer(
              duration: Motion.fast,
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? context.colors.onSurface
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: style.bg,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.colors.outlineVariant),
                ),
              ),
            ),
            const SizedBox(height: Space.xs),
            Text(style.label, style: context.text.labelSmall),
          ],
        ),
      ),
    );
  }
}

/// Rendered at a fixed logical size (360×560) so the exported image is
/// identical on every device.
class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.meal, required this.style});
  final Meal meal;
  final _CardStyle style;

  @override
  Widget build(BuildContext context) {
    final fg = style.fg;
    final muted = fg.withValues(alpha: 0.62);
    final m = meal.macros;
    TextStyle sans(double size, FontWeight w, Color c) => TextStyle(
      fontFamily: AppFonts.sans,
      fontSize: size,
      fontWeight: w,
      color: c,
      height: 1.1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    Widget macro(String label, double g, Color dot) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                child: const SizedBox.square(dimension: 8),
              ),
              const SizedBox(width: 6),
              Text(label, style: sans(12, FontWeight.w600, muted)),
            ],
          ),
          const SizedBox(height: 4),
          Text('${g.round()}g', style: sans(22, FontWeight.w800, fg)),
        ],
      ),
    );

    return SizedBox(
      width: 360,
      height: 560,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: style.bg,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  FoodPhoto(
                    meal.photo,
                    width: 324,
                    height: 260,
                    radius: BorderRadius.circular(22),
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Palette.ink.withValues(alpha: 0.75),
                        borderRadius: Radii.pillAll,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.favorite_rounded,
                              color: Palette.lime,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Health ${meal.healthScore.toStringAsFixed(1)}',
                              style: sans(12, FontWeight.w700, Palette.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                meal.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 28,
                  height: 1.1,
                  color: fg,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    Fmt.kcal(meal.kcal),
                    style: sans(48, FontWeight.w800, fg),
                  ),
                  const SizedBox(width: 6),
                  Text('kcal', style: sans(16, FontWeight.w600, muted)),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  macro('Protein', m.protein, Palette.protein),
                  macro('Carbs', m.carbs, Palette.carbs),
                  macro('Fat', m.fat, Palette.fat),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: fg.withValues(alpha: 0.15), height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  LogoMark(size: 22, inverted: style == _CardStyle.ink),
                  const SizedBox(width: 8),
                  Text('NutriLens', style: sans(14, FontWeight.w800, fg)),
                  const Spacer(),
                  Text(
                    'Scanned in 3 sec',
                    style: sans(12, FontWeight.w600, muted),
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
