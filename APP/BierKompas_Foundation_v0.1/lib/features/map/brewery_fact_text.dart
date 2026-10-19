import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'breweries.dart';

/// Tekst van een weetje van een brouwerij. Een "Website: ..."-weetje wordt een
/// klikbare link die de site in de browser opent.
class BreweryFactText extends StatelessWidget {
  const BreweryFactText({super.key, required this.fact, required this.style, required this.linkColor});

  final String fact;
  final TextStyle style;
  final Color linkColor;

  @override
  Widget build(BuildContext context) {
    final uri = websiteUriFromFact(fact);
    if (uri == null) return Text(fact, style: style);

    final website = fact.substring('Website:'.length).trim();
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          const TextSpan(text: 'Website: '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => launchUrl(uri, mode: LaunchMode.externalApplication),
                child: Text(
                  website,
                  style: style.copyWith(color: linkColor, decoration: TextDecoration.underline, decorationColor: linkColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
