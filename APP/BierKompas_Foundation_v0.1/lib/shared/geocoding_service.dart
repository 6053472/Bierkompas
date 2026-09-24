import 'dart:convert';

import 'package:http/http.dart' as http;

import 'postal_code_utils.dart';

enum GeocodeOutcome {
  /// Adres gevonden, coördinaten beschikbaar.
  found,

  /// De adresopzoekdienst gaf duidelijk aan dat dit adres niet bestaat.
  notFound,

  /// De dienst zelf was niet bereikbaar (geen internet, timeout, storing) --
  /// zegt niets over of het adres klopt. Nooit hierop blokkeren zonder de
  /// gebruiker de kans te geven het opnieuw te proberen.
  serviceUnavailable,
}

class GeocodeResult {
  final GeocodeOutcome outcome;
  final double? latitude;
  final double? longitude;

  const GeocodeResult._(this.outcome, this.latitude, this.longitude);

  factory GeocodeResult.found(double lat, double lon) => GeocodeResult._(GeocodeOutcome.found, lat, lon);
  factory GeocodeResult.notFound() => const GeocodeResult._(GeocodeOutcome.notFound, null, null);
  factory GeocodeResult.serviceUnavailable() => const GeocodeResult._(GeocodeOutcome.serviceUnavailable, null, null);
}

/// Zoekt de coördinaten van een Nederlands adres via de gratis Nominatim-
/// dienst (OpenStreetMap).
///
/// Gebruikt door zowel het evenementenformulier als "Brouwerij toevoegen" om
/// vóór het versturen te controleren dat een adres echt bestaat -- zonder
/// geldige coördinaten verschijnt een evenement/brouwerij namelijk nooit op
/// de kaart, ook al is de aanmelding verder prima ingevuld.
Future<GeocodeResult> geocodeDutchAddress({
  required String street,
  required String houseNumber,
  required String postalCode,
  required String city,
}) async {
  final address =
      '$street $houseNumber, ${normalizeDutchPostalCode(postalCode)} $city, Nederland';
  try {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search?format=json&limit=1&q=${Uri.encodeQueryComponent(address)}',
    );
    final response = await http.get(uri, headers: {'User-Agent': 'BierKompas/1.0'}).timeout(
          const Duration(seconds: 10),
        );
    if (response.statusCode != 200) return GeocodeResult.serviceUnavailable();

    final results = jsonDecode(response.body) as List;
    if (results.isEmpty) return GeocodeResult.notFound();

    final first = results.first as Map<String, dynamic>;
    final lat = double.tryParse(first['lat'] as String? ?? '');
    final lon = double.tryParse(first['lon'] as String? ?? '');
    if (lat == null || lon == null) return GeocodeResult.notFound();

    return GeocodeResult.found(lat, lon);
  } catch (_) {
    return GeocodeResult.serviceUnavailable();
  }
}
