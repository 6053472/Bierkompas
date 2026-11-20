import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// Aanhalingstekens en punthaken horen nooit bij een link ("<https://x.nl>").
final _urlPattern = RegExp(r'''(https?://[^\s<>"']+|www\.[^\s<>"']+)''', caseSensitive: false);

/// Het adres dat bij een tik echt geopend wordt, of null als het geen
/// bruikbare link is.
/// - Afgekapte links ("https://site.nl/.../abc.../info", vaak uit gekopieerde
///   Facebook-teksten) leiden naar een verkeerde pagina: niet klikbaar.
/// - Een Facebook-doorverwijzing (l.facebook.com/l.php?u=...) opent direct de
///   echte site, zonder Facebook-tussenpagina en volgcode (fbclid).
@visibleForTesting
Uri? linkTarget(String url) {
  if (url.contains('...') || url.contains('…')) return null;
  var uri = Uri.tryParse(url.contains('://') ? url : 'https://$url');
  if (uri == null || !uri.host.contains('.')) return null;
  final isFacebookRedirect = RegExp(r'^(l|lm)\.facebook\.com$').hasMatch(uri.host) && uri.path == '/l.php';
  final target = isFacebookRedirect ? Uri.tryParse(uri.queryParameters['u'] ?? '') : null;
  if (target != null && (target.scheme == 'http' || target.scheme == 'https') && target.host.isNotEmpty) {
    final params = Map.of(target.queryParameters)..remove('fbclid');
    uri = Uri(
      scheme: target.scheme,
      host: target.host,
      port: target.hasPort ? target.port : null,
      path: target.path,
      queryParameters: params.isEmpty ? null : params,
      fragment: target.hasFragment ? target.fragment : null,
    );
  }
  return uri;
}

/// Tekst waarin websites (http(s)://... of www....) aanklikbaar zijn en in de
/// browser openen. Voor vrije beschrijvingen van evenementen en horeca.
class LinkifiedText extends StatefulWidget {
  const LinkifiedText(this.text, {super.key, required this.style, this.linkColor = const Color(0xFFD4B28C), this.maxLines});

  final String text;
  final TextStyle style;
  final Color linkColor;
  final int? maxLines;

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in _urlPattern.allMatches(widget.text)) {
      // Leestekens achter een link ("zie www.x.nl.") horen niet bij de link.
      var url = match.group(0)!;
      final trailing = RegExp(r'[.,;:!?)\]]+$').stringMatch(url) ?? '';
      url = url.substring(0, url.length - trailing.length);

      if (match.start > start) spans.add(TextSpan(text: widget.text.substring(start, match.start)));
      final target = linkTarget(url);
      if (target == null) {
        // Geen bruikbare link: gewoon als tekst tonen.
        spans.add(TextSpan(text: url));
        start = match.start + url.length;
        continue;
      }
      final recognizer = TapGestureRecognizer()..onTap = () => _open(target);
      _recognizers.add(recognizer);
      spans.add(TextSpan(
        text: url,
        style: TextStyle(color: widget.linkColor, decoration: TextDecoration.underline, decorationColor: widget.linkColor),
        recognizer: recognizer,
      ));
      start = match.start + url.length;
    }
    if (start < widget.text.length) spans.add(TextSpan(text: widget.text.substring(start)));

    return Text.rich(
      TextSpan(style: widget.style, children: spans),
      maxLines: widget.maxLines,
      overflow: widget.maxLines == null ? null : TextOverflow.ellipsis,
    );
  }

  Future<void> _open(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kon de website niet openen.')));
    }
  }
}
