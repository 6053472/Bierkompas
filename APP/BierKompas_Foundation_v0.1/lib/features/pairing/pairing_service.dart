import 'package:supabase_flutter/supabase_flutter.dart';

class BeerPairing {
  final int id;
  final String brouwerij;
  final String biernaam;
  final String? linkWebsite;
  final String aanbevolenGerecht;
  final String? aankoopContext;
  final String? prijs;
  final String? smaakDrieWoorden;
  final String? proeflokaalSfeer;

  const BeerPairing({
    required this.id,
    required this.brouwerij,
    required this.biernaam,
    required this.aanbevolenGerecht,
    this.linkWebsite,
    this.aankoopContext,
    this.prijs,
    this.smaakDrieWoorden,
    this.proeflokaalSfeer,
  });

  factory BeerPairing.fromJson(Map<String, dynamic> json) => BeerPairing(
        id: json['id'] as int,
        brouwerij: json['brouwerij'] as String,
        biernaam: json['biernaam'] as String,
        aanbevolenGerecht: json['aanbevolen_gerecht'] as String,
        linkWebsite: json['link_website'] as String?,
        aankoopContext: json['aankoop_context'] as String?,
        prijs: json['prijs'] as String?,
        smaakDrieWoorden: json['smaak_drie_woorden'] as String?,
        proeflokaalSfeer: json['proeflokaal_sfeer'] as String?,
      );
}

class PairingException implements Exception {
  final String message;
  PairingException(this.message);

  @override
  String toString() => message;
}

/// Leest de bier-spijscombinaties uit de Supabase-tabel `beer_pairings`
/// (zie supabase/add_beer_pairings.sql), aangeleverd door Huub.
class PairingService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<BeerPairing>> fetchAll() async {
    try {
      final rows = await _client.from('beer_pairings').select().order('brouwerij');
      return (rows as List).map((e) => BeerPairing.fromJson(e as Map<String, dynamic>)).toList();
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205' || e.code == '42P01') return [];
      throw PairingException(e.message);
    }
  }
}
