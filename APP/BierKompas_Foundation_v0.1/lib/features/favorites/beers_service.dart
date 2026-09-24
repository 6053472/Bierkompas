import 'package:supabase_flutter/supabase_flutter.dart';

import 'beers.dart';

bool _customBeersLoaded = false;

/// Haalt bieren op die een beheerder via de admin-pagina heeft aangemaakt
/// (tabel `bieren` in Supabase, id 1000 en hoger -- de 14 vaste bieren met
/// id 1 t/m 14 staan al hardcoded in [beers] en worden hier overgeslagen)
/// en voegt ze toe aan de gedeelde [beers]-lijst. Wordt één keer aangeroepen
/// bij het opstarten van de app (main.dart); mislukt stil als de migratie
/// (supabase/add_bier_toevoegen.sql) nog niet gedraaid is, dan blijft de
/// app gewoon met de 14 vaste bieren werken.
Future<void> loadCustomBeers() async {
  if (_customBeersLoaded) return;
  try {
    final rows = await Supabase.instance.client.from('bieren').select().gte('id', 1000);
    for (final row in (rows as List)) {
      final naam = row['naam'] as String?;
      if (naam == null) continue;
      beers.add(Beer(
        id: row['id'] as int,
        name: naam,
        style: row['stijl'] as String? ?? 'Overig',
        abv: row['abv'] as String? ?? '',
        description: row['beschrijving'] as String? ?? '',
        howMade: row['hoe_gemaakt'] as String? ?? '',
        styleInfo: row['stijl_info'] as String? ?? '',
        imageUrl: row['foto_url'] as String?,
        brewery: row['brouwerij'] as String?,
      ));
    }
    _customBeersLoaded = true;
  } catch (_) {
    // Migratie nog niet gedraaid, of geen verbinding -- app werkt gewoon
    // door met de 14 vaste bieren.
  }
}
