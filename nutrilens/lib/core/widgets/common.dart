import 'package:flutter/material.dart';

import '../theme/theme_x.dart';
import '../theme/tokens.dart';

/// The NutriLens mark: an ink tile holding a lime "lens".
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 32, this.inverted = false});
  final double size;

  /// Lime tile with ink lens — for dark photo backgrounds.
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final tile = inverted ? context.brand.accent : const Color(0xFF14140F);
    final lens = inverted ? const Color(0xFF14140F) : context.brand.accent;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tile,
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: lens, width: size * 0.11),
              ),
              child: SizedBox.square(
                dimension: size * 0.5,
                child: Align(
                  alignment: const Alignment(0.45, -0.45),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: lens,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(dimension: size * 0.1),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.color, this.size = 32});
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.onSurface;
    return Semantics(
      label: 'NutriLens',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LogoMark(size: size, inverted: color != null),
          SizedBox(width: size * 0.3),
          Text(
            'NutriLens',
            style: context.text.titleLarge?.copyWith(
              color: c,
              fontSize: size * 0.62,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// White (or night) card with the standard padding and hairline border.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.xl),
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? context.brand.card,
        borderRadius: Radii.xlAll,
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.xxl,
        Space.sm,
        Space.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: context.text.titleLarge),
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: context.colors.onSurfaceVariant,
                textStyle: context.text.labelMedium,
              ),
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

/// Round translucent button for use on top of photos.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 22),
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.38),
        foregroundColor: Colors.white,
        fixedSize: const Size.square(Sizes.iconButton),
      ),
    );
  }
}

/// Small rounded label, e.g. "92% match".
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    this.icon,
    this.background,
    this.foreground,
  });

  final String label;
  final IconData? icon;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? context.colors.onSurface;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background ?? context.colors.surfaceContainerHigh,
        borderRadius: Radii.pillAll,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.md - 2,
          vertical: Space.xs + 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: Space.xs),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelMedium?.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Designed empty state: visual, one line of why, and the fixing action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Space.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.brand.accent,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Icon(icon, size: 28, color: context.brand.onAccent),
            ),
          ),
          const SizedBox(height: Space.lg),
          Text(
            title,
            style: context.text.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Space.xs),
          Text(
            message,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: Space.lg),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
