import 'package:supabase_flutter/supabase_flutter.dart';

/// Een brouwerij waar je in de buurt kunt overnachten (kaart-tab
/// "Overnachten"), uit de tabel `brewery_stays` (zie
/// supabase/setup_alles_in_een.sql, deel brouwerij_overnachtingen).
class BreweryStay {
  final int id;
  final String name;
  final String place;
  final String? province;
  final String country;
  final String? street;
  final String? postalCode;
  final String? website;
  final double latitude;
  final double longitude;
  final String? description;

  /// De website van de brouwerij noemt zelf een overnachtingsmogelijkheid.
  final bool stayConfirmed;

  const BreweryStay({
    required this.id,
    required this.name,
    required this.place,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.stayConfirmed,
    this.province,
    this.street,
    this.postalCode,
    this.website,
    this.description,
  });

  String get countryName => country == 'BE' ? 'België' : 'Nederland';

  String get address => [
        if (street != null && street!.isNotEmpty) street,
        [postalCode, place].where((s) => s != null && s.isNotEmpty).join(' '),
      ].where((s) => s != null && s.isNotEmpty).join(', ');

  /// Logo (favicon) van de website, net als bij brouwerijen en horeca.
  String? get logoUrl {
    final site = website;
    if (site == null || site.isEmpty) return null;
    final host = Uri.tryParse(site.contains('://') ? site : 'https://$site')?.host ?? '';
    return host.isEmpty ? null : 'https://www.google.com/s2/favicons?domain=$host&sz=128';
  }

  factory BreweryStay.fromRow(Map<String, dynamic> row) => BreweryStay(
        id: row['id'] as int,
        name: row['naam'] as String,
        place: row['plaats'] as String? ?? '',
        province: row['provincie'] as String?,
        country: row['land'] as String? ?? 'NL',
        street: row['straat'] as String?,
        postalCode: row['postcode'] as String?,
        website: row['website'] as String?,
        latitude: (row['latitude'] as num).toDouble(),
        longitude: (row['longitude'] as num).toDouble(),
        description: row['beschrijving'] as String?,
        stayConfirmed: row['verblijf_bevestigd'] as bool? ?? false,
      );
}

class BreweryStaysService {
  SupabaseClient get _client => Supabase.instance.client;

  /// Alle overnachtingen, bevestigde eerst. Gooit een fout als het ophalen
  /// mislukt, zodat de kaart een melding met "Opnieuw" kan tonen.
  Future<List<BreweryStay>> fetchAll() async {
    final rows = await _client
        .from('brewery_stays')
        .select()
        .order('verblijf_bevestigd', ascending: false)
        .order('naam');
    return (rows as List).map((row) => BreweryStay.fromRow(row as Map<String, dynamic>)).toList();
  }
}
