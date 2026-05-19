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
  late final String _viewId;
  web.HTMLIFrameElement? _iframe;
  JSFunction? _msgListener;
  bool _ready = false;
  String? _blobUrl;

  @override
  void initState() {
    super.initState();
    _viewId = 'jukebox-${DateTime.now().microsecondsSinceEpoch}';
    _createIframe();
    _msgListener = ((JSAny? raw) => _handleMessage(raw)).toJS;
    web.window.addEventListener('message', _msgListener!);
  }

  void _createIframe() {
    final seek = _calcSeek();
    final html = _buildHtml(widget.videoId, seek, widget.isPlaying);

    // Serve the HTML as a blob so our page controls the JS context —
    // no cross-origin postMessage issues, no "listening" registration needed.
    final blobParts = <JSAny>[html.toJS].toJS;
    final blob = web.Blob(blobParts, web.BlobPropertyBag(type: 'text/html'));
    _blobUrl = web.URL.createObjectURL(blob);

    final iframe = web.HTMLIFrameElement()
      ..src = _blobUrl!
      ..allow = 'autoplay; encrypted-media'
      ..style.opacity = '0'
      ..style.position = 'absolute'
      ..style.pointerEvents = 'none'
      ..style.width = '1px'
      ..style.height = '1px';
    _iframe = iframe;

    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int id) => iframe,
    );
  }

  double _calcSeek() {
    if (widget.isPlaying) {
      return (DateTime.now().millisecondsSinceEpoch - widget.startedAt) /
          1000.0;
    }
    return widget.pausedAt / 1000.0;
  }

  void _syncPlayer() {
    if (!_ready) return;
    final seek = _calcSeek();
    _sendCmd('seekTo', [seek, true]);
    if (widget.isPlaying) {
      _sendCmd('playVideo', []);
    } else {
      _sendCmd('pauseVideo', []);
    }
  }

  void _sendCmd(String func, List<dynamic> args) {
    final msg = jsonEncode({'func': func, 'args': args});
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
      if (data['jukebox'] != true) return;
      final event = data['event'] as String?;
      if (event == 'ready') {
        _ready = true;
        _syncPlayer();
      } else if (event == 'ended') {
        widget.onTrackEnded?.call();
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(JukeboxWebPlayer old) {
    super.didUpdateWidget(old);
    // videoId changes cause full widget recreation via ValueKey(currentIndex)
    // in JukeboxPlayer, so only sync-state changes land here.
    if (old.isPlaying != widget.isPlaying ||
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
    if (_blobUrl != null) {
      web.URL.revokeObjectURL(_blobUrl!);
    }
    super.dispose();
  }

  // Mirrors native player HTML. Uses window.parent.postMessage instead of
  // FlutterYT.postMessage, and receives commands via window.addEventListener.
  static String _buildHtml(String videoId, double seekSeconds, bool isPlaying) {
    final autoCmd = isPlaying ? 'player.playVideo();' : 'player.pauseVideo();';
    final safeId = videoId.replaceAll("'", "\\'");
    return '''<!DOCTYPE html>
<html>
<head>
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body { background: #000; width: 100%; height: 100%; overflow: hidden; }
#p { width: 100%; height: 100%; }
</style>
</head>
<body>
<div id="p"></div>
<script>
window.addEventListener('message', function(e) {
  if (e.source !== window.parent) return;
  if (!player) return;
  try {
    var d = JSON.parse(e.data);
    if (d.func === 'seekTo') player.seekTo(d.args[0], d.args[1]);
    else if (d.func === 'playVideo') player.playVideo();
    else if (d.func === 'pauseVideo') player.pauseVideo();
  } catch(_) {}
});
var tag = document.createElement('script');
tag.src = 'https://www.youtube.com/iframe_api';
document.head.appendChild(tag);
var player;
function onYouTubeIframeAPIReady() {
  player = new YT.Player('p', {
    videoId: '$safeId',
    playerVars: { autoplay: ${isPlaying ? 1 : 0}, controls: 0, playsinline: 1, rel: 0 },
    events: {
      onReady: function() {
        player.seekTo($seekSeconds, true);
        $autoCmd
        window.parent.postMessage(JSON.stringify({jukebox: true, event: 'ready'}), '*');
      },
      onStateChange: function(e) {
        if (e.data === 0) {
          window.parent.postMessage(JSON.stringify({jukebox: true, event: 'ended'}), '*');
        }
      }
    }
  });
}
</script>
</body>
</html>''';
  }

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 1, child: HtmlElementView(viewType: _viewId));
}
