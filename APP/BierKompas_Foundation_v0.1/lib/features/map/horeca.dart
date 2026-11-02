const horecaItemType = 'horeca';

/// Een horecagelegenheid (café, proeflokaal, bierbar) die via "Horeca
/// toevoegen" is aangemeld en door een beheerder is goedgekeurd
/// (zie horeca_submission_service.dart en supabase/add_horeca_submissions.sql).
class HorecaVenue {
  final int id;
  final String title;
  final String location;
  final String about;
  final double latitude;
  final double longitude;
  final String? imageUrl;

  /// Website van de zaak (uit de horecalijst van de klant), of null.
  final String? website;

  /// Logo (favicon) van de website, via dezelfde Google-dienst als bij de
  /// brouwerijen. Null zonder website.
  String? get logoUrl {
    final site = website;
    if (site == null || site.isEmpty) return null;
    final host = Uri.tryParse(site.contains('://') ? site : 'https://$site')?.host ?? '';
    return host.isEmpty ? null : 'https://www.google.com/s2/favicons?domain=$host&sz=128';
  }

  const HorecaVenue({
    required this.id,
    required this.title,
    required this.location,
    required this.about,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
    this.website,
  });
}
