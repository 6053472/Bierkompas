/// Website van een evenement, met dezelfde regels als het beheerpaneel
/// (admin/index.html, eventWebsite): leeg -> null, "www.x.nl" -> "https://www.x.nl",
/// alleen http(s) met een echte domeinnaam. Ongeldig -> null.
String? normalizeEventWebsite(String raw) {
  var value = raw.trim();
  if (value.isEmpty || RegExp(r'\s').hasMatch(value)) return null;
  if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(value)) {
    value = 'https://$value';
  }
  final uri = Uri.tryParse(value);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (!RegExp(r'^[^.\s]+(\.[^.\s]+)+$').hasMatch(uri.host)) return null;
  return value;
}
