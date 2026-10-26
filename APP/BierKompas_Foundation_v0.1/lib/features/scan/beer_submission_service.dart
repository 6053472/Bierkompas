import 'package:supabase_flutter/supabase_flutter.dart';

import '../favorites/beers.dart';

class BeerSubmissionException implements Exception {
  final String message;
  BeerSubmissionException(this.message);

  @override
  String toString() => message;
}

/// Aanmelden van een onbekend bier (tabel `beer_submissions`, zie
/// supabase/add_bier_aanmelden.sql). Het bier komt pas voor iedereen in
/// Bierkompas nadat een beheerder het heeft goedgekeurd.
class BeerSubmissionService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<void> submit({
    required String userId,
    required String naam,
    required String brouwerij,
    String? stijl,
    String? abv,
    String? beschrijving,
    String? barcode,
    String? photoUrl,
  }) async {
    String? orNull(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
    try {
      await _client.from('beer_submissions').insert({
        'user_id': userId,
        'naam': naam.trim(),
        'brouwerij': brouwerij.trim(),
        'stijl': orNull(stijl),
        'abv': orNull(abv),
        'beschrijving': orNull(beschrijving),
        'barcode': orNull(barcode),
        'photo_url': photoUrl,
      });
    } on PostgrestException catch (e) {
      throw BeerSubmissionException(
        e.code == '42P01' || e.code == 'PGRST205'
            ? 'Bieren aanmelden is nog niet beschikbaar. Probeer het later opnieuw.'
            : 'Aanmelden mislukt: ${e.message}',
      );
    }
  }

  /// Bieren die al in Bierkompas staan en op [naam] lijken, zodat de
  /// gebruiker niet per ongeluk een bestaand bier opnieuw aanmeldt.
  List<Beer> findSimilar(String naam) {
    final query = _normalize(naam);
    if (query.length < 3) return const [];
    return beers.where((b) {
      final name = _normalize(b.name);
      return name.contains(query) || (name.length >= 3 && query.contains(name));
    }).take(5).toList();
  }

  static String _normalize(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
