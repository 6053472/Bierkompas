import 'package:supabase_flutter/supabase_flutter.dart';

import 'breweries.dart';

bool _breweriesLoaded = false;

/// Haalt de brouwerijen op uit de tabel `breweries`
/// (supabase/add_builtin_content.sql) en vervangt daarmee de vaste lijst uit
/// breweries.dart, zodat een beheerder ze via het admin-paneel kan bewerken en
/// verwijderen. Wordt één keer aangeroepen bij het opstarten van de app
/// (main.dart). Is de tabel er nog niet of leeg, dan blijft de vaste lijst staan.
Future<void> loadBreweries() async {
  if (_breweriesLoaded) return;
  try {
    final rows = (await Supabase.instance.client
            .from('breweries')
            .select()
            .order('id')
            .range(0, 4999)) as List;
    if (rows.isEmpty) return;
    breweries
      ..clear()
      ..addAll(rows.map((row) => Brewery(
            id: row['id'] as int,
            title: row['title'] as String,
            distance: '',
            rating: '-',
            tags: List<String>.from(row['tags'] as List? ?? const []),
            location: (row['location'] as String?) ?? '',
            about: (row['about'] as String?) ?? '',
            facts: List<String>.from(row['facts'] as List? ?? const []),
            founded: row['founded'] as String?,
            latitude: (row['latitude'] as num).toDouble(),
            longitude: (row['longitude'] as num).toDouble(),
            imageUrl: row['image_url'] as String?,
          )));
    _breweriesLoaded = true;
  } catch (_) {
    // Migratie nog niet gedraaid, of geen verbinding -- vaste lijst blijft.
  }
}
