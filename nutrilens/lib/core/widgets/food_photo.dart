import 'package:flutter/material.dart';

import '../theme/theme_x.dart';

/// A food photograph with a themed placeholder and graceful failure.
/// Decodes at display size so large photos don't waste memory.
class FoodPhoto extends StatelessWidget {
  const FoodPhoto(
    this.path, {
    super.key,
    this.width,
    this.height,
    this.radius = BorderRadius.zero,
    this.semanticLabel,
    this.fit = BoxFit.cover,
  });

  final String? path;
  final double? width;
  final double? height;
  final BorderRadius radius;
  final String? semanticLabel;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final placeholder = ColoredBox(
      color: context.colors.surfaceContainerHigh,
      child: Center(
        child: Icon(
          Icons.restaurant_rounded,
          color: context.colors.outline,
          size: 24,
        ),
      ),
    );
    final p = path;
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: width,
        height: height,
        child: p == null
            ? placeholder
            : Image.asset(
                p,
                fit: fit,
                cacheWidth: width == null ? null : (width! * dpr).round(),
                semanticLabel: semanticLabel,
                excludeFromSemantics: semanticLabel == null,
                frameBuilder: (context, child, frame, sync) {
                  if (sync) return child;
                  return AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(milliseconds: 220),
                    child: child,
                  );
                },
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}
