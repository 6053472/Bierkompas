import 'package:supabase_flutter/supabase_flutter.dart';

/// Resultaat van het loggen van een gescand bier: bijgewerkte stats en de
/// badges die net (opnieuw) vrijgespeeld zijn.
class BeerScanLogResult {
  final int beersTasted;
  final int breweriesExplored;
  final List<String> newlyEarnedBadgeIds;

  const BeerScanLogResult({
    required this.beersTasted,
    required this.breweriesExplored,
    required this.newlyEarnedBadgeIds,
  });
}

class BeerScanException implements Exception {
  final String message;
  const BeerScanException(this.message);
}

/// Praat met de Supabase-functie `log_beer_scan` die een gescand bier koppelt
/// aan het Bier-paspoort van de gebruiker (zie supabase/add_beer_scan.sql).
class BeerScanService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<BeerScanLogResult> logScan({
    required String userId,
    required int beerId,
    String? brewery,
  }) async {
    try {
      final rows = await _client.rpc('log_beer_scan', params: {
        'p_user_id': userId,
        'p_beer_id': beerId,
        'p_brewery': brewery,
      });
      final row = (rows as List).first as Map<String, dynamic>;
      return BeerScanLogResult(
        beersTasted: row['beers_tasted'] as int? ?? 0,
        breweriesExplored: row['breweries_explored'] as int? ?? 0,
        newlyEarnedBadgeIds: (row['newly_earned_badges'] as List? ?? const [])
            .map((b) => b as String)
            .toList(),
      );
    } catch (e) {
      throw const BeerScanException('Kon het bier niet loggen. Probeer het opnieuw.');
    }
  }
}
