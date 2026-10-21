import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/postal_code_utils.dart';

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

  /// Welke tickets er zijn (kolommen ticket_regular/_beer/_vip zijn
  /// ja/nee-velden, geen bedragen).
  final bool ticketRegular;
  final bool ticketBeer;
  final bool ticketVip;
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
    this.ticketRegular = false,
    this.ticketBeer = false,
    this.ticketVip = false,
    this.price = 0,
  });
}

/// Haalt goedgekeurde evenementen op en bepaalt hun positie op de kaart.
/// Heeft een evenement opgeslagen coördinaten (kolommen latitude/longitude),
/// dan worden die gebruikt; anders wordt het adres omgezet via dezelfde
/// gratis Nominatim-dienst (OpenStreetMap) die ook bij het aanmelden van een
/// brouwerij gebruikt wordt. Opgezochte adressen worden op het toestel
/// onthouden, zodat dat maar één keer per adres hoeft. Evenementen waarvan
/// het adres niet gevonden kan worden, komen niet als pin op de kaart, maar
/// blijven wel gewoon in de Agenda-lijst staan.
class EventMapService {
  SupabaseClient get _client => Supabase.instance.client;

  static const _cacheKey = 'event_geocode_cache_v1';

  /// Geeft de evenementen terug. [onProgress] wordt direct aangeroepen met de
  /// evenementen waarvan de positie al bekend is (opgeslagen coördinaten of
  /// eerder opgezocht), en daarna telkens opnieuw als er opgezochte adressen
  /// bij zijn gekomen -- zo staan de pins er meteen i.p.v. pas als alles
  /// (één adres per seconde) is opgezocht.
  Future<List<EventPin>> fetchApprovedWithCoordinates({void Function(List<EventPin>)? onProgress}) async {
    final List rows;
    try {
      rows = await _client.from('events').select().eq('status', 'approved') as List;
    } catch (_) {
      // Geen verbinding, of onverwachte tabelstructuur -- kaart blijft
      // gewoon werken zonder evenement-pins.
      return const [];
    }

    final prefs = await SharedPreferences.getInstance();
    final cache = <String, List<dynamic>>{};
    try {
      final raw = prefs.getString(_cacheKey);
      if (raw != null) {
        (jsonDecode(raw) as Map<String, dynamic>).forEach((k, v) => cache[k] = v as List<dynamic>);
      }
    } catch (_) {}

    final events = <EventPin>[];
    final toGeocode = <(Map<String, dynamic>, String)>[];
    for (final row in rows.cast<Map<String, dynamic>>()) {
      final lat = (row['latitude'] as num?)?.toDouble();
      final lon = (row['longitude'] as num?)?.toDouble();
      if (lat != null && lon != null) {
        _addPin(events, row, lat, lon);
        continue;
      }
      final address = _buildAddress(row);
      if (address == null) continue;
      final cached = cache[address];
      if (cached != null && cached.length == 2) {
        _addPin(events, row, (cached[0] as num).toDouble(), (cached[1] as num).toDouble());
      } else {
        toGeocode.add((row, address));
      }
    }
    onProgress?.call(List.of(events));

    // Nominatim staat ongeveer één aanvraag per seconde toe.
    var changed = false;
    for (var i = 0; i < toGeocode.length; i++) {
      final (row, address) = toGeocode[i];
      final coords = await _geocode(address);
      if (coords != null) {
        cache[address] = [coords.$1, coords.$2];
        _addPin(events, row, coords.$1, coords.$2);
        changed = true;
      }
      if (changed && (i % 5 == 4 || i == toGeocode.length - 1)) {
        onProgress?.call(List.of(events));
        await prefs.setString(_cacheKey, jsonEncode(cache));
        changed = false;
      }
      await Future.delayed(const Duration(milliseconds: 1100));
    }

    return events;
  }

  void _addPin(List<EventPin> events, Map<String, dynamic> row, double lat, double lon) {
    try {
      events.add(EventPin(
        id: row['id'] as int,
        name: row['name'] as String? ?? 'Naamloos evenement',
        eventType: row['event_type'] as String? ?? 'Festival',
        startDate: DateTime.tryParse(row['start_date'] as String? ?? '') ?? DateTime.now(),
        locationName: row['location_name'] as String?,
        city: row['city'] as String?,
        description: row['description'] as String?,
        ticketRegular: row['ticket_regular'] == true,
        ticketBeer: row['ticket_beer'] == true,
        ticketVip: row['ticket_vip'] == true,
        price: (row['price'] as num?)?.toDouble() ?? 0,
        latitude: lat,
        longitude: lon,
      ));
    } catch (_) {
      // Eén onvolledig evenement mag de andere pins niet tegenhouden.
    }
  }

  String? _buildAddress(Map<String, dynamic> row) {
    final street = row['street'] as String?;
    final city = row['city'] as String?;
    if ((street == null || street.isEmpty) && (city == null || city.isEmpty)) return null;
    final houseNumber = row['house_number'] as String? ?? '';
    final postalCode = normalizeDutchPostalCode(row['postal_code'] as String? ?? '');
    return '${street ?? ''} $houseNumber, $postalCode ${city ?? ''}, ${countryForPostalCode(postalCode)}';
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
