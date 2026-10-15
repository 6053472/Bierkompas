import 'package:supabase_flutter/supabase_flutter.dart';

import 'music.dart';

bool _customSongsLoaded = false;

/// Haalt de nummers op uit de tabel `music_tracks` en zet ze in de gedeelde
/// [songs]-lijst. Wordt één keer aangeroepen bij het opstarten van de app
/// (main.dart).
///
/// Staan de vaste nummers al in de database (supabase/add_builtin_content.sql,
/// herkenbaar aan `builtin_key`), dan is de database leidend: wat een beheerder
/// daar aanpast of verwijdert, geldt ook in de app. Anders blijven de vaste
/// nummers uit de code staan en komen de door een beheerder toegevoegde
/// nummers erbij. Mislukt stil als de migratie nog niet gedraaid is.
Future<void> loadCustomSongs() async {
  if (_customSongsLoaded) return;
  try {
    final rows = (await Supabase.instance.client
            .from('music_tracks')
            .select()
            .order('sort_order')
            .order('id')) as List;
    final dbSongs = rows.map((row) => Song(
          id: (row['builtin_key'] as String?) ?? 'db_${row['id']}',
          title: row['title'] as String,
          artist: row['artist'] as String,
          coverAsset: (row['cover_asset'] as String?) ?? '',
          coverUrl: row['cover_url'] as String?,
          customListenUrl: row['listen_url'] as String?,
          featured: (row['featured'] as bool?) ?? false,
        ));
    final databaseIsLeading = rows.any((row) => row['builtin_key'] != null);
    if (databaseIsLeading) songs.clear();
    songs.addAll(dbSongs);
    _customSongsLoaded = true;
  } catch (_) {
    // Migratie nog niet gedraaid, of geen verbinding -- vaste nummers blijven.
  }
}
