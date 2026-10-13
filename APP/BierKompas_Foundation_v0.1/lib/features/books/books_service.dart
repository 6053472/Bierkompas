import 'package:supabase_flutter/supabase_flutter.dart';

import 'books.dart';

bool _customBooksLoaded = false;

/// Haalt boeken op die een beheerder via de admin-pagina heeft toegevoegd
/// (tabel `library_books`) en voegt ze toe aan de gedeelde [books]-lijst. Wordt
/// één keer aangeroepen bij het opstarten van de app (main.dart); mislukt stil
/// als de migratie (supabase/add_admin_content_management.sql) nog niet
/// gedraaid is, dan blijft de app gewoon met de vaste boeken werken.
Future<void> loadCustomBooks() async {
  if (_customBooksLoaded) return;
  try {
    final rows = await Supabase.instance.client.from('library_books').select().order('sort_order').order('id');
    for (final row in (rows as List)) {
      books.add(Book(
        id: 'db_${row['id']}',
        title: row['title'] as String,
        author: row['author'] as String,
        subtitle: row['subtitle'] as String?,
        coverAsset: '',
        coverUrl: row['cover_url'] as String?,
      ));
    }
    _customBooksLoaded = true;
  } catch (_) {
    // Migratie nog niet gedraaid, of geen verbinding -- vaste boeken blijven.
  }
}
