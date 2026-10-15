import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class EmbedView extends StatefulWidget {
  final String url;

  const EmbedView({super.key, required this.url});

  @override
  State<EmbedView> createState() => _EmbedViewState();
}

class _EmbedViewState extends State<EmbedView> {
  late final WebViewController _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(Colors.black)
    ..loadRequest(Uri.parse(widget.url));

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);
}
