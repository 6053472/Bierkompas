import 'package:supabase_flutter/supabase_flutter.dart';

import 'books.dart';

/// De vaste boeken uit de code, bewaard bij de eerste keer laden zodat een
/// herlaadactie weer vanaf die lijst kan beginnen.
List<Book>? _builtinBooks;

String? _nonEmpty(Object? value) {
  final text = (value as String?)?.trim();
  return text == null || text.isEmpty ? null : text;
}

/// Haalt de boeken op uit de tabel `library_books` en zet ze in de gedeelde
/// [books]-lijst. Wordt bij het opstarten aangeroepen (main.dart) en opnieuw
/// telkens als de boekenpagina opent, zodat boeken die een beheerder net heeft
/// toegevoegd of aangepast meteen zichtbaar zijn zonder de app te herstarten.
///
/// Staan de vaste boeken al in de database (supabase/add_builtin_content.sql,
/// herkenbaar aan `builtin_key`), dan is de database leidend: wat een beheerder
/// daar aanpast of verwijdert, geldt ook in de app. Anders blijven de vaste
/// boeken uit de code staan en komen de door een beheerder toegevoegde boeken
/// erbij. Mislukt stil (geen verbinding, migratie niet gedraaid): de huidige
/// lijst blijft dan staan.
Future<void> loadCustomBooks() async {
  _builtinBooks ??= List.of(books);
  try {
    final rows = (await Supabase.instance.client
            .from('library_books')
            .select()
            .order('sort_order')
            .order('id')) as List;
    final dbBooks = rows.map((row) => Book(
          id: (row['builtin_key'] as String?) ?? 'db_${row['id']}',
          title: row['title'] as String,
          author: row['author'] as String,
          subtitle: row['subtitle'] as String?,
          coverAsset: (row['cover_asset'] as String?) ?? '',
          coverUrl: row['cover_url'] as String?,
          caption: _nonEmpty(row['caption']),
          externalUrl: _nonEmpty(row['external_url']),
        )).toList();
    final databaseIsLeading = rows.any((row) => row['builtin_key'] != null);
    books
      ..clear()
      ..addAll(databaseIsLeading ? const [] : _builtinBooks!)
      ..addAll(dbBooks);
  } catch (_) {
    // Geen verbinding of migratie nog niet gedraaid -- huidige lijst blijft.
  }
}
