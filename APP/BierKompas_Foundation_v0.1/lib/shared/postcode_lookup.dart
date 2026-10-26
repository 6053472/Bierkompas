import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'postal_code_utils.dart';

/// Straat en plaats bij een Nederlandse postcode.
class PostcodeAddress {
  final String street;
  final String city;

  const PostcodeAddress({required this.street, required this.city});
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
    );
  } catch (e) {
    debugPrint('Postcode opzoeken mislukt: $e');
    return null;
  }
}
