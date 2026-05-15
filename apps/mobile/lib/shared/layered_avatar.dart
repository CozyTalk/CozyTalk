import 'package:flutter/material.dart';
import 'avatar_overlay.dart';

// Renders UserAvatar.png with optional accessory and mood overlays.
//
// Positions are stored relative to HomeScreen's 270px card where the avatar
// sits at top:118. This widget recomputes them so the same values work at any
// [boxSize].  clipBehavior is Clip.none so hats extend above the box edge.
class LayeredAvatar extends StatelessWidget {
  final double boxSize;
  final AvatarOverlay? moodOverlay;
  final AvatarOverlay? accessoryOverlay;

  // Overlay coordinates in AvatarOverlay are calibrated for a 90px avatar.
  static const double _refAvatarTop = 118;
  static const double _refAvatarSize = 90.0;

  const LayeredAvatar({
    super.key,
    this.boxSize = 90,
    this.moodOverlay,
    this.accessoryOverlay,
  });

  double get _scale => boxSize / _refAvatarSize;

  // Convert HomeScreen card coordinate → local box coordinate, scaled to boxSize
  double _top(AvatarOverlay o) => (o.top - _refAvatarTop) * _scale;
  double _left(AvatarOverlay o) =>
      boxSize / 2 + o.cx * _scale - (o.w * _scale) / 2;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: boxSize,
      height: boxSize,
      child: Stack(
        clipBehavior: Clip.none, // lets hats render above the box
        children: [
          // Base avatar
          Image.asset(
            'assets/images/UserAvatar.png',
            width: boxSize,
            height: boxSize,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Container(
              width: boxSize,
              height: boxSize,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(boxSize / 4),
              ),
              child: const Icon(Icons.person, color: Colors.grey),
            ),
          ),

          // Accessory layer (hats go under mood; glasses go above mood)
          if (accessoryOverlay != null && !accessoryOverlay!.aboveMood)
            Positioned(
              top: _top(accessoryOverlay!),
              left: _left(accessoryOverlay!),
              child: Image.asset(
                accessoryOverlay!.path,
                width: accessoryOverlay!.w * _scale,
                height: accessoryOverlay!.h * _scale,
                fit: BoxFit.contain,
              ),
            ),

          // Mood layer
          if (moodOverlay != null)
            Positioned(
              top: _top(moodOverlay!),
              left: _left(moodOverlay!),
              child: Image.asset(
                moodOverlay!.path,
                width: moodOverlay!.w * _scale,
                height: moodOverlay!.h * _scale,
                fit: BoxFit.contain,
              ),
            ),

          // Glasses render above mood
          if (accessoryOverlay != null && accessoryOverlay!.aboveMood)
            Positioned(
              top: _top(accessoryOverlay!),
              left: _left(accessoryOverlay!),
              child: Image.asset(
                accessoryOverlay!.path,
                width: accessoryOverlay!.w * _scale,
                height: accessoryOverlay!.h * _scale,
                fit: BoxFit.contain,
              ),
            ),
        ],
      ),
    );
  }
}
