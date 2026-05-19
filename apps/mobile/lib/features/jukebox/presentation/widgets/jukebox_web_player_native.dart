import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
  WebViewController? _controller;
  bool _available = false;

  @override
  void initState() {
    super.initState();
    try {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..addJavaScriptChannel(
          'FlutterYT',
          onMessageReceived: (msg) {
            if (msg.message == 'ended') widget.onTrackEnded?.call();
          },
        )
        ..loadHtmlString(
          _buildHtml(widget.videoId, _seekSeconds(), widget.isPlaying),
        );
      _available = true;
    } catch (_) {}
  }

  @override
  void didUpdateWidget(JukeboxWebPlayer old) {
    super.didUpdateWidget(old);
    if (old.videoId != widget.videoId) {
      _controller?.loadHtmlString(
        _buildHtml(widget.videoId, _seekSeconds(), widget.isPlaying),
      );
    } else if (old.isPlaying != widget.isPlaying ||
        old.startedAt != widget.startedAt ||
        old.pausedAt != widget.pausedAt) {
      final seek = _seekSeconds();
      final cmd = widget.isPlaying
          ? 'player.playVideo();'
          : 'player.pauseVideo();';
      _controller?.runJavaScript('if(player){player.seekTo($seek,true);$cmd}');
    }
  }

  double _seekSeconds() {
    if (widget.isPlaying) {
      return (DateTime.now().millisecondsSinceEpoch - widget.startedAt) /
          1000.0;
    }
    return widget.pausedAt / 1000.0;
  }

  static String _buildHtml(String videoId, double seekSeconds, bool isPlaying) {
    final autoCmd = isPlaying ? 'player.playVideo();' : 'player.pauseVideo();';
    return '''
<!DOCTYPE html>
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
  var tag = document.createElement('script');
  tag.src = 'https://www.youtube.com/iframe_api';
  document.head.appendChild(tag);
  var player;
  function onYouTubeIframeAPIReady() {
    player = new YT.Player('p', {
      videoId: '$videoId',
      playerVars: { autoplay: 1, controls: 1, playsinline: 1, rel: 0 },
      events: {
        onReady: function() {
          player.seekTo($seekSeconds, true);
          $autoCmd
        },
        onStateChange: function(e) {
          if (e.data === 0) FlutterYT.postMessage('ended');
        }
      }
    });
  }
</script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    if (!_available || _controller == null) return const SizedBox.shrink();
    return SizedBox(height: 56, child: WebViewWidget(controller: _controller!));
  }
}
