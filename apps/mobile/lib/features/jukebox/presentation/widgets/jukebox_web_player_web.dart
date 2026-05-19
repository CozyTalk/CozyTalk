import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

// ── YouTube IFrame API — loaded once per page lifetime ────────────────────────

Completer<void>? _ytApiReady;

Future<void> _ensureYtApi() {
  if (_ytApiReady != null) return _ytApiReady!.future;
  _ytApiReady = Completer<void>();

  // Already loaded (e.g. after hot-reload).
  if ((web.window as JSObject).getProperty('YT'.toJS) != null) {
    _ytApiReady!.complete();
    return _ytApiReady!.future;
  }

  // YouTube calls this global when the API script finishes loading.
  (web.window as JSObject).setProperty(
    'onYouTubeIframeAPIReady'.toJS,
    (() {
      if (!_ytApiReady!.isCompleted) _ytApiReady!.complete();
    }).toJS,
  );

  final script = web.document.createElement('script') as web.HTMLScriptElement;
  script.src = 'https://www.youtube.com/iframe_api';
  web.document.head!.append(script);
  return _ytApiReady!.future;
}

// dart:js_interop_unsafe cannot call constructors directly.
// Inject a tiny shim once; YT is defined by the time it is called.
bool _shimInjected = false;

void _ensureShim() {
  if (_shimInjected) return;
  _shimInjected = true;
  final s = web.document.createElement('script') as web.HTMLScriptElement;
  s.text = 'window._ytNew=function(el,o){return new YT.Player(el,o);};';
  web.document.head!.append(s);
}

// ── Widget ────────────────────────────────────────────────────────────────────

class JukeboxWebPlayer extends StatefulWidget {
  final String videoId;
  final int startedAt;
  final int pausedAt;
  final bool isPlaying;
  final VoidCallback? onTrackEnded;

  const JukeboxWebPlayer({
    super.key,
    required this.videoId,
    required this.startedAt,
    required this.pausedAt,
    required this.isPlaying,
    this.onTrackEnded,
  });

  @override
  State<JukeboxWebPlayer> createState() => _JukeboxWebPlayerState();
}

class _JukeboxWebPlayerState extends State<JukeboxWebPlayer> {
  JSObject? _player;
  bool _ready = false;
  web.HTMLDivElement? _div;

  @override
  void initState() {
    super.initState();
    _ensureShim();
    _ensureYtApi().then((_) {
      if (mounted) _spawnPlayer();
    });
  }

  void _spawnPlayer() {
    // Append a hidden div to the main page DOM. YT.Player injects its iframe
    // here as a direct child of the Flutter Web page — same origin, so
    // autoplay-with-sound works (no nested blob-URL iframe chain).
    final div = web.document.createElement('div') as web.HTMLDivElement;
    div.style.cssText =
        'position:fixed;top:-9999px;left:-9999px;width:0;height:0;';
    web.document.body!.append(div);
    _div = div;

    final playerVars = JSObject()
      ..setProperty('autoplay'.toJS, (widget.isPlaying ? 1 : 0).toJS)
      ..setProperty('controls'.toJS, 1.toJS)
      ..setProperty('playsinline'.toJS, 1.toJS)
      ..setProperty('rel'.toJS, 0.toJS)
      ..setProperty('mute'.toJS, 0.toJS);

    final events = JSObject()
      ..setProperty(
        'onReady'.toJS,
        ((JSAny? _) {
          _ready = true;
          _player?.callMethod('unMute'.toJS);
          _player?.callMethod('setVolume'.toJS, 100.toJS);
          _syncPlayer();
        }).toJS,
      )
      ..setProperty(
        'onStateChange'.toJS,
        ((JSAny? e) {
          try {
            final data = (e as JSObject).getProperty('data'.toJS);
            if (data == null) return;
            final state = (data as JSNumber).toDartDouble.toInt();
            if (state == 0) widget.onTrackEnded?.call();
          } catch (_) {}
        }).toJS,
      );

    final opts = JSObject()
      ..setProperty('width'.toJS, 0.toJS)
      ..setProperty('height'.toJS, 0.toJS)
      ..setProperty('videoId'.toJS, widget.videoId.toJS)
      ..setProperty('playerVars'.toJS, playerVars)
      ..setProperty('events'.toJS, events);

    final result = (web.window as JSObject).callMethod(
      '_ytNew'.toJS,
      div as JSAny,
      opts as JSAny,
    );
    _player = result as JSObject?;
  }

  double _calcSeek() {
    if (widget.isPlaying) {
      return (DateTime.now().millisecondsSinceEpoch - widget.startedAt) /
          1000.0;
    }
    return widget.pausedAt / 1000.0;
  }

  void _syncPlayer() {
    if (!_ready || _player == null) return;
    final seek = _calcSeek();
    _player!.callMethod('seekTo'.toJS, seek.toJS, true.toJS);
    if (widget.isPlaying) {
      _player!.callMethod('unMute'.toJS);
      _player!.callMethod('setVolume'.toJS, 100.toJS);
      _player!.callMethod('playVideo'.toJS);
    } else {
      _player!.callMethod('pauseVideo'.toJS);
    }
  }

  @override
  void didUpdateWidget(JukeboxWebPlayer old) {
    super.didUpdateWidget(old);
    // videoId changes cause full widget recreation via ValueKey(currentIndex).
    if (old.isPlaying != widget.isPlaying ||
        old.startedAt != widget.startedAt ||
        old.pausedAt != widget.pausedAt) {
      _syncPlayer();
    }
  }

  @override
  void dispose() {
    try {
      _player?.callMethod('destroy'.toJS);
    } catch (_) {}
    _div?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
