import 'package:flutter/material.dart';

/// Wraps any widget with a subtle scale-down press animation.
class PressBounceBtn extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scale;

  const PressBounceBtn({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.88,
  });

  @override
  State<PressBounceBtn> createState() => _PressBounceState();
}

class _PressBounceState extends State<PressBounceBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
