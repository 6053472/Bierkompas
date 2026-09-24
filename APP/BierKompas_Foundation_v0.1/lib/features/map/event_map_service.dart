import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Een goedgekeurd evenement zoals getoond op de Kaart, met coördinaten
/// zodat het als pin kan worden geplaatst.
class EventPin {
  final int id;
  final String name;
  final String eventType;
  final DateTime startDate;
  final String? locationName;
  final String? city;
  final String? description;
  final double? ticketRegular;
  final double? ticketBeer;
  final double? ticketVip;
  final double price;
  final double latitude;
  final double longitude;

  const EventPin({
    required this.id,
    required this.name,
    required this.eventType,
    required this.startDate,
    required this.latitude,
    required this.longitude,
    this.locationName,
    this.city,
    this.description,
    this.ticketRegular,
    this.ticketBeer,
    this.ticketVip,
    this.price = 0,
  });
}

/// Haalt goedgekeurde evenementen op en bepaalt hun positie op de kaart.
/// Evenementen hebben (nog) geen opgeslagen coördinaten, dus wordt het adres
/// per evenement omgezet via dezelfde gratis Nominatim-dienst (OpenStreetMap)
/// die ook bij het aanmelden van een brouwerij gebruikt wordt. Evenementen
/// waarvan het adres niet gevonden kan worden, worden overgeslagen (komen
/// gewoon niet als pin op de kaart, maar blijven wel gewoon in de Agenda-lijst
/// staan -- deze service raakt die lijst niet aan).
class EventMapService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<EventPin>> fetchApprovedWithCoordinates() async {
    try {
      final rows = await _client.from('events').select().eq('status', 'approved');
      final events = <EventPin>[];

      for (final row in (rows as List)) {
        final address = _buildAddress(row);
        if (address == null) continue;
        final coords = await _geocode(address);
        if (coords == null) continue;

        events.add(EventPin(
          id: row['id'] as int,
          name: row['name'] as String? ?? 'Naamloos evenement',
          eventType: row['event_type'] as String? ?? 'Festival',
          startDate: DateTime.tryParse(row['start_date'] as String? ?? '') ?? DateTime.now(),
          locationName: row['location_name'] as String?,
          city: row['city'] as String?,
          description: row['description'] as String?,
          ticketRegular: (row['ticket_regular'] as num?)?.toDouble(),
          ticketBeer: (row['ticket_beer'] as num?)?.toDouble(),
          ticketVip: (row['ticket_vip'] as num?)?.toDouble(),
          price: (row['price'] as num?)?.toDouble() ?? 0,
          latitude: coords.$1,
          longitude: coords.$2,
        ));
      }

      return events;
    } catch (_) {
      // Geen verbinding, of onverwachte tabelstructuur -- kaart blijft
      // gewoon werken zonder evenement-pins.
      return const [];
    }
  }

  String? _buildAddress(Map<String, dynamic> row) {
    final street = row['street'] as String?;
    final city = row['city'] as String?;
    if ((street == null || street.isEmpty) && (city == null || city.isEmpty)) return null;
    final houseNumber = row['house_number'] as String? ?? '';
    final postalCode = row['postal_code'] as String? ?? '';
    return '${street ?? ''} $houseNumber, $postalCode ${city ?? ''}, Nederland';
  }

  Future<(double, double)?> _geocode(String address) async {
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
}
