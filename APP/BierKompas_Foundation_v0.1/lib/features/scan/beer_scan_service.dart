import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../favorites/beers.dart';

/// Resultaat van het loggen van een gescand bier: bijgewerkte stats en de
/// badges die net (opnieuw) vrijgespeeld zijn.
class BeerScanLogResult {
  final int beersTasted;
  final int breweriesExplored;
  final int currentStreak;
  final int longestStreak;
  final List<String> newlyEarnedBadgeIds;

  const BeerScanLogResult({
    required this.beersTasted,
    required this.breweriesExplored,
    required this.currentStreak,
    required this.longestStreak,
    required this.newlyEarnedBadgeIds,
  });
}

class ScannedBeer {
  final Beer beer;
  final DateTime scannedAt;

  /// Eigen foto van het bier/etiket, alleen aanwezig als die is toegevoegd
  /// via "Foto uploaden" i.p.v. barcode scannen.
  final String? photoUrl;

  const ScannedBeer({required this.beer, required this.scannedAt, this.photoUrl});
}

class BeerScanException implements Exception {
  final String message;
  const BeerScanException(this.message);
}

/// Praat met de Supabase-functie `log_beer_scan` die een gescand bier koppelt
/// aan het Bier-paspoort van de gebruiker (zie supabase/add_beer_scan.sql).
class BeerScanService {
  SupabaseClient get _client => Supabase.instance.client;

  /// Zoekt welk bier bij deze gescande barcode hoort. De koppeling
  /// barcode -> bier-id staat in Supabase (tabel `bieren`, beheerd via de
  /// admin-pagina), zodat een beheerder barcodes kan instellen zonder dat de
  /// app opnieuw gebouwd hoeft te worden. De bierinhoud zelf (naam, stijl,
  /// foto, ...) komt nog uit de statische lijst in beers.dart.
  /// Geeft null terug als de barcode bij geen enkel bier hoort -- er wordt
  /// nooit teruggevallen op een andere bron, dus nooit een ander product.
  Future<Beer?> findBeerByBarcode(String barcode) async {
    try {
      final row = await _client.from('bieren').select('id').eq('barcode', barcode).maybeSingle();
      if (row == null) return null;
      final id = row['id'] as int;
      for (final beer in beers) {
        if (beer.id == id) return beer;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Alle bieren die de gebruiker gescand heeft (nieuwste eerst), uit
  /// `user_beer_logs`. Bieren die niet meer in de bierlijst staan worden
  /// overgeslagen.
  Future<List<ScannedBeer>> listScannedBeers() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    try {
      // Bewust '*' i.p.v. een vaste kolomlijst: zo blijft dit werken op een
      // database waar add_beer_scan_photo.sql nog niet is uitgevoerd (dan is
      // photo_url simpelweg altijd null i.p.v. de hele lijst te laten falen).
      final rows = await _client
          .from('user_beer_logs')
          .select()
          .eq('user_id', userId)
          .order('logged_at', ascending: false);
      final result = <ScannedBeer>[];
      for (final row in rows as List) {
        final id = row['beer_id'] as int;
        for (final beer in beers) {
          if (beer.id == id) {
            result.add(ScannedBeer(
              beer: beer,
              scannedAt: DateTime.parse(row['logged_at'] as String).toLocal(),
              photoUrl: row['photo_url'] as String?,
            ));
            break;
          }
        }
      }
      return result;
    } catch (_) {
      throw const BeerScanException('Kon je gescande bieren niet laden.');
    }
  }

  /// Uploadt een eigen foto van het bier/etiket (alternatief voor barcode
  /// scannen -- er is geen automatische etiketherkenning, de gebruiker kiest
  /// zelf welk bier het is).
  Future<String> uploadPhoto({required String userId, required Uint8List bytes}) async {
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from('beer-scan-photos').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    return _client.storage.from('beer-scan-photos').getPublicUrl(path);
  }

  Future<BeerScanLogResult> logScan({
    required String userId,
    required int beerId,
    String? brewery,
    String? photoUrl,
  }) async {
    try {
      // p_photo_url wordt alleen meegestuurd als er echt een foto is: zo
      // blijft een gewone barcode-scan werken op een database waar
      // add_beer_scan_photo.sql nog niet is uitgevoerd (oude functiesignatuur
      // zonder dat argument).
      final rows = await _client.rpc('log_beer_scan', params: {
        'p_user_id': userId,
        'p_beer_id': beerId,
        'p_brewery': brewery,
        if (photoUrl != null) 'p_photo_url': photoUrl,
      });
      final row = (rows as List).first as Map<String, dynamic>;
      return BeerScanLogResult(
        beersTasted: row['beers_tasted'] as int? ?? 0,
        breweriesExplored: row['breweries_explored'] as int? ?? 0,
        currentStreak: row['current_streak'] as int? ?? 0,
        longestStreak: row['longest_streak'] as int? ?? 0,
        newlyEarnedBadgeIds: (row['newly_earned_badges'] as List? ?? const [])
            .map((b) => b as String)
            .toList(),
      );
    } catch (e) {
      throw const BeerScanException('Kon het bier niet loggen. Probeer het opnieuw.');
    }
  }
}
