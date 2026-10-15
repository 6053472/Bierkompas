import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

final Set<String> _registeredViews = {};

class EmbedView extends StatelessWidget {
  final String url;

  const EmbedView({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final viewType = 'bierkompas-embed-${url.hashCode}';
    if (_registeredViews.add(viewType)) {
      ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
        final frame = web.document.createElement('iframe') as web.HTMLIFrameElement
          ..src = url
          ..allow = 'autoplay; encrypted-media; fullscreen; picture-in-picture';
        frame.style
          ..border = 'none'
          ..width = '100%'
          ..height = '100%';
        return frame;
      });
    }
    return HtmlElementView(viewType: viewType);
  }
}
