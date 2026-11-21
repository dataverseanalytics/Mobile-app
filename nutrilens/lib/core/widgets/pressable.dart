import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// Tactile press: scales to 0.97 while held, with a selection haptic.
/// Wraps children that are visually cards or tiles.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.semanticLabel,
    this.haptic = true,
    this.scale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool haptic;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      enabled: widget.onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap?.call();
              },
        child: AnimatedScale(
          scale: _down && !reduce ? widget.scale : 1,
          duration: Motion.fast,
          curve: Motion.enter,
          child: widget.child,
        ),
      ),
    );
  }
}
