import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

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
  String _viewId = '';
  web.HTMLIFrameElement? _iframe;
  JSFunction? _msgListener;
  // Prevent re-entrant seeks when YouTube fires a stateChange=2 during our own
  // seekTo call. We suppress the auto-resume for 2 seconds after each command.
  bool _suppressExternalPause = false;

  @override
  void initState() {
    super.initState();
    _viewId = _makeViewId(widget.videoId);
    _createIframe();
    _msgListener = ((JSAny? raw) => _handleMessage(raw)).toJS;
    web.window.addEventListener('message', _msgListener!);
  }

  @override
  void didUpdateWidget(JukeboxWebPlayer old) {
    super.didUpdateWidget(old);
    if (old.videoId != widget.videoId) {
      // New track — recreate iframe entirely.
      web.window.removeEventListener('message', _msgListener!);
      _viewId = _makeViewId(widget.videoId);
      _createIframe();
      _msgListener = ((JSAny? raw) => _handleMessage(raw)).toJS;
      web.window.addEventListener('message', _msgListener!);
      setState(() {});
    } else if (old.isPlaying != widget.isPlaying ||
        old.startedAt != widget.startedAt ||
        old.pausedAt != widget.pausedAt) {
      _syncPlayer();
    }
  }

  @override
  void dispose() {
    if (_msgListener != null) {
      web.window.removeEventListener('message', _msgListener!);
    }
    super.dispose();
  }

  String _makeViewId(String videoId) => 'jukebox-yt-${videoId.hashCode}';

  void _createIframe() {
    final iframe = web.HTMLIFrameElement()
      ..src =
          'https://www.youtube.com/embed/${widget.videoId}'
          '?enablejsapi=1&autoplay=1&playsinline=1&rel=0&origin=${Uri.encodeComponent('http://localhost')}'
      ..allow = 'autoplay; encrypted-media'
      ..style.opacity = '0'
      ..style.position = 'absolute'
      ..style.pointerEvents = 'none'
      ..style.width = '1px'
      ..style.height = '1px';
    _iframe = iframe;

    // Register/replace the platform view factory so Flutter can render it.
    // registerViewFactory is idempotent for an already-registered viewId when
    // the factory is replaced, but we use unique IDs per videoId so it's always new.
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int id) => iframe,
    );
  }

  void _syncPlayer() {
    final seekSeconds = widget.isPlaying
        ? (DateTime.now().millisecondsSinceEpoch - widget.startedAt) / 1000.0
        : widget.pausedAt / 1000.0;
    _suppressExternalPause = true;
    _sendCommand('seekTo', [seekSeconds, true]);
    if (widget.isPlaying) {
      _sendCommand('playVideo', []);
    } else {
      _sendCommand('pauseVideo', []);
    }
    Future.delayed(
      const Duration(seconds: 2),
      () => _suppressExternalPause = false,
    );
  }

  void _sendCommand(String func, List<dynamic> args) {
    final msg = jsonEncode({'event': 'command', 'func': func, 'args': args});
    _iframe?.contentWindow?.postMessage(msg.toJS, '*'.toJS);
  }

  void _handleMessage(JSAny? rawEvent) {
    try {
      final msg = rawEvent as web.MessageEvent;
      final raw = (msg.data?.dartify() ?? '').toString();
      if (raw.isEmpty) return;

      final Map<String, dynamic> data;
      try {
        data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {
        return;
      }

      if (data['event'] == 'onReady') {
        _syncPlayer();
        return;
      }

      if (data['event'] == 'onStateChange') {
        final info = data['info'];
        if (info == 0) {
          // Ended
          widget.onTrackEnded?.call();
        } else if (info == 2 && !_suppressExternalPause && widget.isPlaying) {
          // User paused inside the invisible iframe (shouldn't happen but guard
          // against desync by re-sending play).
          _sendCommand('playVideo', []);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 1, child: HtmlElementView(viewType: _viewId));
}
