import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Locatie van een vriend die op dit moment deelt (zie
/// supabase/add_friend_locations.sql, functie list_friend_locations).
class NearbyFriend {
  final String friendId;
  final String name;
  final String? avatarUrl;
  final double latitude;
  final double longitude;
  final DateTime updatedAt;

  const NearbyFriend({
    required this.friendId,
    required this.name,
    this.avatarUrl,
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
  });
}

class FriendLocationException implements Exception {
  final String message;
  const FriendLocationException(this.message);

  @override
  String toString() => message;
}

/// Regelt "Bierliefhebbers in de buurt": je eigen live locatie delen met
/// bevestigde vrienden (alleen na expliciete toestemming), en de locaties
/// van vrienden ophalen die op hun beurt delen. Zie
/// supabase/add_friend_locations.sql.
class FriendLocationService {
  SupabaseClient get _client => Supabase.instance.client;

  /// Vraagt locatietoestemming en zorgt dat de locatievoorziening van het
  /// toestel aanstaat. Gooit een duidelijke foutmelding als dat niet lukt.
  Future<Position> _determinePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const FriendLocationException(
        'Locatievoorziening staat uit. Zet deze aan in je systeeminstellingen.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const FriendLocationException('Locatietoestemming geweigerd.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const FriendLocationException(
        'Locatietoestemming is permanent geweigerd. Zet deze aan bij de app-instellingen van je toestel.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  /// Of de ingelogde gebruiker zijn locatie momenteel deelt.
  Future<bool> isSharingEnabled() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      final row = await _client
          .from('friend_locations')
          .select('sharing_enabled')
          .eq('user_id', userId)
          .maybeSingle();
      return row?['sharing_enabled'] as bool? ?? false;
    } on PostgrestException {
      return false;
    }
  }

  /// Zet locatie delen aan of uit. Bij aanzetten wordt meteen de huidige
  /// positie opgehaald en weggeschreven; bij uitzetten wordt alleen de vlag
  /// omgezet (geen locatiedata meer zichtbaar voor vrienden).
  Future<void> setSharingEnabled(bool enabled) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    if (!enabled) {
      try {
        await _client.from('friend_locations').update({'sharing_enabled': false}).eq('user_id', userId);
      } on PostgrestException catch (e) {
        throw FriendLocationException(e.message);
      }
      return;
    }

    final position = await _determinePosition();
    try {
      await _client.from('friend_locations').upsert({
        'user_id': userId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'sharing_enabled': true,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } on PostgrestException catch (e) {
      throw FriendLocationException(e.message);
    }
  }

  /// Werkt de eigen locatie bij (alleen zinvol als delen al aanstaat).
  /// Fouten worden genegeerd: dit draait op de achtergrond terwijl de kaart
  /// open staat.
  Future<void> pushCurrentLocation() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final position = await _determinePosition();
      await _client.from('friend_locations').update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);
    } catch (_) {
      // stilzwijgend negeren, draait op de achtergrond
    }
  }

  /// Locaties van vrienden die momenteel delen.
  Future<List<NearbyFriend>> fetchNearby() async {
    try {
      final rows = await _client.rpc('list_friend_locations');
      return (rows as List).map((row) {
        return NearbyFriend(
          friendId: row['friend_id'] as String,
          name: row['name'] as String? ?? 'Onbekend',
          avatarUrl: row['avatar_url'] as String?,
          latitude: row['latitude'] as double,
          longitude: row['longitude'] as double,
          updatedAt: DateTime.parse(row['updated_at'] as String),
        );
      }).toList();
    } on PostgrestException {
      return const [];
    }
  }
}
