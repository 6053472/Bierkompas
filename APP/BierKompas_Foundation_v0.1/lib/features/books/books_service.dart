import 'package:supabase_flutter/supabase_flutter.dart';

import 'books.dart';

bool _customBooksLoaded = false;

/// Haalt de boeken op uit de tabel `library_books` en zet ze in de gedeelde
/// [books]-lijst. Wordt één keer aangeroepen bij het opstarten van de app
/// (main.dart).
///
/// Staan de vaste boeken al in de database (supabase/add_builtin_content.sql,
/// herkenbaar aan `builtin_key`), dan is de database leidend: wat een beheerder
/// daar aanpast of verwijdert, geldt ook in de app. Anders blijven de vaste
/// boeken uit de code staan en komen de door een beheerder toegevoegde boeken
/// erbij. Mislukt stil als de migratie nog niet gedraaid is.
Future<void> loadCustomBooks() async {
  if (_customBooksLoaded) return;
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
        ));
    final databaseIsLeading = rows.any((row) => row['builtin_key'] != null);
    if (databaseIsLeading) books.clear();
    books.addAll(dbBooks);
    _customBooksLoaded = true;
  } catch (_) {
    // Migratie nog niet gedraaid, of geen verbinding -- vaste boeken blijven.
  }
}
