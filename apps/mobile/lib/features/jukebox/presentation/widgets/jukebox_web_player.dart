import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class JukeboxWebPlayer extends StatefulWidget {
  final String embedUrl;
  const JukeboxWebPlayer({super.key, required this.embedUrl});

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
        ..setBackgroundColor(Colors.transparent)
        ..loadRequest(Uri.parse(widget.embedUrl));
      _available = true;
    } catch (_) {}
  }

  @override
  void didUpdateWidget(JukeboxWebPlayer old) {
    super.didUpdateWidget(old);
    if (old.embedUrl != widget.embedUrl) {
      _controller?.loadRequest(Uri.parse(widget.embedUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_available || _controller == null) return const SizedBox.shrink();
    return SizedBox(
      height: 150,
      child: WebViewWidget(controller: _controller!),
    );
  }
}
