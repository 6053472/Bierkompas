import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/geocoding_service.dart';
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
    final geocode = await geocodeDutchAddress(
      street: street,
      houseNumber: houseNumber,
      postalCode: postalCode,
      city: city,
    );

    if (geocode.outcome == GeocodeOutcome.notFound) {
      throw const BrewerySubmissionException(
        'Dit adres kon niet gevonden worden. Controleer straat, huisnummer, postcode en plaats.',
      );
    }
    if (geocode.outcome == GeocodeOutcome.serviceUnavailable) {
      throw const BrewerySubmissionException(
        'Kon het adres niet controleren (geen verbinding). Probeer het opnieuw.',
      );
    }

    try {
      await _client.from('brewery_submissions').insert({
        'user_id': userId,
        'naam': naam,
        'beschrijving': beschrijving,
        'street': street,
        'house_number': houseNumber,
        'postal_code': postalCode,
        'city': city,
        'latitude': geocode.latitude,
        'longitude': geocode.longitude,
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
