import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'breweries.dart';

class BrewerySubmissionException implements Exception {
  final String message;
  const BrewerySubmissionException(this.message);

  @override
  String toString() => message;
}

/// Regelt het aanmelden van een eigen brouwerij voor de kaart: adres
/// automatisch omzetten naar coördinaten, foto uploaden, en de aanmelding
/// wegschrijven zodat een beheerder 'm kan goedkeuren (zie
/// supabase/add_brewery_submissions.sql).
class BrewerySubmissionService {
  SupabaseClient get _client => Supabase.instance.client;

  /// Zoekt de coördinaten van een adres via dezelfde gratis Nominatim-dienst
  /// (OpenStreetMap) die de Kaart-pagina al gebruikt voor locatiezoeken.
  /// Geeft null terug als het adres niet gevonden kan worden -- de aanmelding
  /// kan dan nog steeds worden ingediend, alleen zonder positie op de kaart
  /// totdat dat handmatig wordt hersteld.
  Future<(double, double)?> geocodeAddress(String address) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&limit=1&q=${Uri.encodeQueryComponent(address)}',
      );
      final response = await http.get(uri, headers: {'User-Agent': 'BierKompas/1.0'});
      if (response.statusCode != 200) return null;
      final results = jsonDecode(response.body) as List;
      if (results.isEmpty) return null;
      final first = results.first as Map<String, dynamic>;
      final lat = double.tryParse(first['lat'] as String? ?? '');
      final lon = double.tryParse(first['lon'] as String? ?? '');
      if (lat == null || lon == null) return null;
      return (lat, lon);
    } catch (_) {
      return null;
    }
  }

  Future<String> uploadPhoto({required String userId, required Uint8List bytes}) async {
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from('brewery-photos').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    return _client.storage.from('brewery-photos').getPublicUrl(path);
  }

  Future<void> submit({
    required String userId,
    required String naam,
    required String beschrijving,
    required String street,
    required String houseNumber,
    required String postalCode,
    required String city,
    String? photoUrl,
  }) async {
    final address = '$street $houseNumber, $postalCode $city, Nederland';
    final coords = await geocodeAddress(address);

    try {
      await _client.from('brewery_submissions').insert({
        'user_id': userId,
        'naam': naam,
        'beschrijving': beschrijving,
        'street': street,
        'house_number': houseNumber,
        'postal_code': postalCode,
        'city': city,
        'latitude': coords?.$1,
        'longitude': coords?.$2,
        'photo_url': photoUrl,
      });
    } catch (e) {
      throw const BrewerySubmissionException('Aanmelden mislukt. Probeer het later opnieuw.');
    }
  }

  /// Goedgekeurde aanmeldingen, klaar om op de kaart te tonen naast de vaste
  /// lijst en de OSM-brouwerijen. Aanmeldingen zonder coördinaten (geocoding
  /// mislukt) worden overgeslagen.
  Future<List<Brewery>> fetchApproved() async {
    try {
      final rows = await _client
          .from('brewery_submissions')
          .select()
          .eq('status', 'approved')
          .not('latitude', 'is', null)
          .not('longitude', 'is', null);

      return (rows as List).map((row) {
        // Aparte id-reeks (ver uit de buurt van de vaste lijst) zodat er geen
        // botsing ontstaat met de handmatig genummerde brouwerijen/OSM-data.
        final submissionId = row['id'] as int;
        return Brewery(
          id: 900000 + submissionId,
          title: row['naam'] as String,
          distance: '',
          rating: '-',
          tags: const ['COMMUNITY'],
          location: row['city'] as String? ?? '',
          about: row['beschrijving'] as String? ?? '',
          facts: const [],
          latitude: row['latitude'] as double,
          longitude: row['longitude'] as double,
          imageUrl: row['photo_url'] as String?,
        );
      }).toList();
    } catch (_) {
      // Migratie nog niet gedraaid, of geen verbinding -- gewoon leeg
      // teruggeven, de rest van de kaart blijft dan werken.
      return const [];
    }
  }
}
