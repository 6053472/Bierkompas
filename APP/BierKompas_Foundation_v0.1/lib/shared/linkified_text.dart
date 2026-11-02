import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

final _urlPattern = RegExp(r'(https?://[^\s]+|www\.[^\s]+)', caseSensitive: false);

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
      final recognizer = TapGestureRecognizer()..onTap = () => _open(url);
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

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url.contains('://') ? url : 'https://$url');
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kon de website niet openen.')));
    }
  }
}
