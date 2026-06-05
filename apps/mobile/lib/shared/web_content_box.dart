import 'package:flutter/material.dart';

class WebContentBox extends StatelessWidget {
  final Widget child;
  const WebContentBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: child,
      ),
    );
  }
}
