import 'package:flutter_riverpod/flutter_riverpod.dart';

// Pixel position is expressed relative to HomeScreen's 270px-tall avatar card
// where UserAvatar.png sits at top:118, left:center-45, size:90×90.
// LayeredAvatar recomputes positions for any target box size automatically.
class AvatarOverlay {
  final String path;
  final double top;      // from card top in HomeScreen (270px card)
  final double cx;       // horizontal offset from avatar horizontal centre
  final double w;
  final double h;
  final bool aboveMood;  // true → renders above the mood layer (e.g. glasses)

  const AvatarOverlay({
    required this.path,
    required this.top,
    this.cx = 0,
    required this.w,
    required this.h,
    this.aboveMood = false,
  });
}

// ── Centralised data specs ────────────────────────────────────────
class AvatarOverlays {
  AvatarOverlays._();

  static const Map<String, AvatarOverlay> mood = {
    'Happy':    AvatarOverlay(path: 'assets/images/Happy.png',    top: 130, cx: 0, w: 35, h: 35),
    'Thrilled': AvatarOverlay(path: 'assets/images/Thrilled.png', top: 130, cx: 0, w: 36, h: 36),
    'Sad':      AvatarOverlay(path: 'assets/images/Sad.png',      top: 130, cx: 0, w: 36, h: 36),
    'Lonely':   AvatarOverlay(path: 'assets/images/Lonely.png',   top: 130, cx: 0, w: 35, h: 35),
    'Silly':    AvatarOverlay(path: 'assets/images/Silly.png',    top: 130, cx: 0, w: 35, h: 35),
    'Grumpy':   AvatarOverlay(path: 'assets/images/Grumpy.png',   top: 127, cx: 0, w: 38, h: 38),
  };

  static const Map<String, AvatarOverlay> accessory = {
    'Cap':          AvatarOverlay(path: 'assets/images/Cap.png',          top: 100, cx: -4, w: 56, h: 50),
    'Beanie':       AvatarOverlay(path: 'assets/images/Pinkbeanie.png',   top: 97, cx: 0, w: 52, h: 46),
    'Witch':        AvatarOverlay(path: 'assets/images/WitchHat.png',     top: 82, cx: 0, w: 60, h: 70),
    'Glasses':      AvatarOverlay(path: 'assets/images/Sunglasses.png',   top: 134, cx: 0, w: 60, h: 24, aboveMood: true),
    'Cat Headband': AvatarOverlay(path: 'assets/images/CatHeadband.png',  top: 97, cx: 1, w: 67, h: 65),
    'Crown':        AvatarOverlay(path: 'assets/images/Crown.png',        top: 100, cx: 0, w: 52, h: 32),
  };
}

// ── Shared state ──────────────────────────────────────────────────
class AvatarState {
  final AvatarOverlay? mood;
  final AvatarOverlay? accessory;
  const AvatarState({this.mood, this.accessory});

}

class AvatarNotifier extends Notifier<AvatarState> {
  @override
  AvatarState build() => const AvatarState();

  void setMood(AvatarOverlay? v) =>
      state = AvatarState(mood: v, accessory: state.accessory);

  void setAccessory(AvatarOverlay? v) =>
      state = AvatarState(mood: state.mood, accessory: v);
}

final avatarProvider =
    NotifierProvider<AvatarNotifier, AvatarState>(AvatarNotifier.new);
