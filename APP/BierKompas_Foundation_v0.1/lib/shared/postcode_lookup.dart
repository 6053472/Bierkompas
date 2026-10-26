import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'postal_code_utils.dart';

/// Straat, plaats en provincie bij een Nederlandse postcode.
class PostcodeAddress {
  final String street;
  final String city;
  final String province;

  const PostcodeAddress({required this.street, required this.city, this.province = ''});
}

/// Provincie bij een Belgische postcode. De eerste cijfers van een Belgische
/// postcode bepalen de provincie, dus hiervoor is geen externe dienst nodig.
/// Postcodes 1000-1299 horen bij het Brussels Hoofdstedelijk Gewest (geen
/// provincie). Null bij een ongeldige postcode.
String? belgianProvinceForPostcode(String postcode) {
  if (!isBelgianPostalCode(postcode)) return null;
  final code = int.parse(postcode.trim());
  if (code < 1300) return 'Brussel';
  if (code < 1500) return 'Waals-Brabant';
  if (code < 2000) return 'Vlaams-Brabant';
  if (code < 3000) return 'Antwerpen';
  if (code < 3500) return 'Vlaams-Brabant';
  if (code < 4000) return 'Limburg';
  if (code < 5000) return 'Luik';
  if (code < 6000) return 'Namen';
  if (code < 6600) return 'Henegouwen';
  if (code < 7000) return 'Luxemburg';
  if (code < 8000) return 'Henegouwen';
  if (code < 9000) return 'West-Vlaanderen';
  return 'Oost-Vlaanderen';
}

/// Zoekt straat en plaats op bij een Nederlandse postcode via de gratis
/// PDOK Locatieserver. Bij een Belgische of ongeldige postcode, of als de
/// dienst niet reageert, komt er null terug: de velden blijven dan gewoon
/// handmatig in te vullen.
Future<PostcodeAddress?> lookupDutchPostcode(String postcode) async {
  final normalized = postcode.replaceAll(' ', '').toUpperCase();
  if (!isDutchPostalCode(normalized)) return null;

  try {
    final uri = Uri.https(
      'api.pdok.nl',
      '/bzk/locatieserver/search/v3_1/free',
      {
        'q': 'postcode:$normalized',
        'fq': 'type:adres',
        'rows': '1',
      },
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final docs = (data['response'] as Map<String, dynamic>?)?['docs'] as List<dynamic>?;
    if (docs == null || docs.isEmpty) return null;

    final first = docs.first as Map<String, dynamic>;
    return PostcodeAddress(
      street: first['straatnaam']?.toString() ?? '',
      city: first['woonplaatsnaam']?.toString() ?? '',
      province: first['provincienaam']?.toString() ?? '',
    );
  } catch (e) {
    debugPrint('Postcode opzoeken mislukt: $e');
    return null;
  }
}
