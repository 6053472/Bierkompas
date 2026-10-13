import 'package:supabase_flutter/supabase_flutter.dart';

import 'music.dart';

bool _customSongsLoaded = false;

/// Haalt nummers op die een beheerder via de admin-pagina heeft toegevoegd
/// (tabel `music_tracks`) en voegt ze toe aan de gedeelde [songs]-lijst. Wordt
/// één keer aangeroepen bij het opstarten van de app (main.dart); mislukt stil
/// als de migratie (supabase/add_admin_content_management.sql) nog niet
/// gedraaid is, dan blijft de app gewoon met de vaste nummers werken.
Future<void> loadCustomSongs() async {
  if (_customSongsLoaded) return;
  try {
    final rows = await Supabase.instance.client.from('music_tracks').select().order('sort_order').order('id');
    for (final row in (rows as List)) {
      songs.add(Song(
        id: 'db_${row['id']}',
        title: row['title'] as String,
        artist: row['artist'] as String,
        coverAsset: '',
        coverUrl: row['cover_url'] as String?,
        customListenUrl: row['listen_url'] as String?,
      ));
    }
    _customSongsLoaded = true;
  } catch (_) {
    // Migratie nog niet gedraaid, of geen verbinding -- vaste nummers blijven.
  }
}
