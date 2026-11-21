import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/theme_x.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/food_photo.dart';
import '../../core/widgets/scan_frame.dart';
import '../../data/models.dart';
import '../../data/scan_repository.dart';
import '../../state/providers.dart';

/// Camera capture. The viewfinder shows a demo photo until the `camera`
/// plugin is wired in; every control and state is already designed.
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key, this.barcode = false});
  final bool barcode;

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with SingleTickerProviderStateMixin {
  late bool _barcode = widget.barcode;
  late final String _photo = ref.read(scanRepositoryProvider).nextPhoto();
  bool _flash = false;
  bool _busy = false;
  late final AnimationController _flashFx = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  @override
  void dispose() {
    _flashFx.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_busy) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    setState(() => _busy = true);
    unawaited(HapticFeedback.heavyImpact());
    if (!reduceMotion) {
      await _flashFx.forward(from: 0);
      await _flashFx.reverse();
    }
    if (!mounted) return;

    if (_barcode) {
      final product = await ref
          .read(scanRepositoryProvider)
          .lookupBarcode(ScanRepository.demoBarcode);
      if (!mounted) return;
      final now = DateTime.now();
      ref
          .read(scanDraftProvider.notifier)
          .set(
            Meal(
              id: 'meal-${now.microsecondsSinceEpoch}',
              name: product.name,
              photo: product.photo,
              loggedAt: now,
              type: MealType.forTime(now),
              healthScore: 8.4,
              items: [
                FoodItem(
                  id: 'bc-1',
                  name: product.name,
                  unit: product.unit,
                  macros: product.macros,
                ),
              ],
            ),
          );
      context.pushReplacement(Routes.result);
      return;
    }
    context.pushReplacement(
      '${Routes.analyzing}?photo=${Uri.encodeComponent(_photo)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final frameW = size.width - Space.huge * 2;
    final frameH = _barcode ? frameW * 0.55 : frameW;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            FoodPhoto(
              _photo,
              width: size.width,
              semanticLabel: 'Camera viewfinder',
            ),
            // Dim everything outside the frame.
            IgnorePointer(
              child: CustomPaint(
                painter: _CutoutPainter(
                  hole: Rect.fromCenter(
                    center: Offset(size.width / 2, size.height * 0.44),
                    width: frameW,
                    height: frameH,
                  ),
                  color: Colors.black.withValues(alpha: 0.55),
                ),
              ),
            ),
            Positioned(
              left: (size.width - frameW) / 2,
              top: size.height * 0.44 - frameH / 2,
              width: frameW,
              height: frameH,
              child: AnimatedSwitcher(
                duration: Motion.base,
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  children: [...previous, ?current],
                ),
                // AnimatedSwitcher loosens constraints; force full size.
                child: ScanFrame(
                  key: ValueKey(_barcode),
                  color: context.brand.accent,
                  child: _barcode
                      ? Center(
                          child: Container(
                            height: 2,
                            margin: const EdgeInsets.symmetric(
                              horizontal: Space.xl,
                            ),
                            color: context.brand.accent.withValues(alpha: 0.8),
                          ),
                        )
                      : null,
                ),
              ),
            ),
            Positioned(
              left: Space.gutter,
              right: Space.gutter,
              top: size.height * 0.44 + frameH / 2 + Space.lg,
              child: Text(
                _barcode
                    ? 'Line up the barcode inside the frame'
                    : 'Fit the whole plate inside the frame',
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(color: Colors.white),
              ),
            ),
            FadeTransition(
              opacity: _flashFx,
              child: const IgnorePointer(
                child: ColoredBox(color: Colors.white),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _TopControls(
                    flash: _flash,
                    onFlash: () => setState(() => _flash = !_flash),
                  ),
                  const Spacer(),
                  _ModeSwitch(
                    barcode: _barcode,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      setState(() => _barcode = v);
                    },
                  ),
                  const SizedBox(height: Space.xl),
                  _BottomControls(
                    photo: _photo,
                    busy: _busy,
                    onCapture: _capture,
                    onSearch: () => context.pushReplacement(Routes.search),
                  ),
                  const SizedBox(height: Space.lg),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopControls extends ConsumerWidget {
  const _TopControls({required this.flash, required this.onFlash});
  final bool flash;
  final VoidCallback onFlash;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premium = ref.watch(premiumProvider);
    final left = ref.watch(freeScansProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.sm,
      ),
      child: Row(
        children: [
          GlassIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Close camera',
            onPressed: () => context.pop(),
          ),
          const Spacer(),
          if (!premium)
            Pill(
              icon: Icons.bolt_rounded,
              label: '$left free ${left == 1 ? 'scan' : 'scans'} left',
              background: Colors.black.withValues(alpha: 0.45),
              foreground: Colors.white,
            ),
          const Spacer(),
          GlassIconButton(
            icon: flash ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            tooltip: flash ? 'Turn flash off' : 'Turn flash on',
            onPressed: onFlash,
          ),
        ],
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.barcode, required this.onChanged});
  final bool barcode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, IconData icon, bool value) {
      final selected = barcode == value;
      return Semantics(
        selected: selected,
        button: true,
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: Motion.fast,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: Radii.pillAll,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? Colors.black : Colors.white,
                ),
                const SizedBox(width: Space.xs + 2),
                Text(
                  label,
                  style: context.text.labelMedium?.copyWith(
                    color: selected ? Colors.black : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: Radii.pillAll,
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            seg('Food', Icons.restaurant_rounded, false),
            seg('Barcode', Icons.qr_code_scanner_rounded, true),
          ],
        ),
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.photo,
    required this.busy,
    required this.onCapture,
    required this.onSearch,
  });

  final String photo;
  final bool busy;
  final VoidCallback onCapture;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Semantics(
          button: true,
          label: 'Choose from gallery',
          child: Tooltip(
            message: 'Choose from gallery',
            child: InkWell(
              onTap: busy ? null : onCapture,
              borderRadius: Radii.mdAll,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: Radii.mdAll,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: FoodPhoto(
                  photo,
                  width: 48,
                  height: 48,
                  radius: Radii.smAll,
                ),
              ),
            ),
          ),
        ),
        Semantics(
          button: true,
          label: 'Take photo',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: busy ? null : onCapture,
            child: Container(
              width: 82,
              height: 82,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: AnimatedContainer(
                duration: Motion.fast,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: busy ? context.brand.accent : Colors.white,
                ),
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: busy ? null : onSearch,
          tooltip: 'Search instead',
          icon: const Icon(Icons.keyboard_rounded),
          style: IconButton.styleFrom(
            backgroundColor: Colors.black.withValues(alpha: 0.45),
            foregroundColor: Colors.white,
            fixedSize: const Size.square(52),
          ),
        ),
      ],
    );
  }
}

class _CutoutPainter extends CustomPainter {
  _CutoutPainter({required this.hole, required this.color});
  final Rect hole;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(22)));
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CutoutPainter old) =>
      old.hole != hole || old.color != color;
}
