import 'package:supabase_flutter/supabase_flutter.dart';

/// Voegt [row] toe aan [table]. Bestaat een van de [optionalColumns] (nog)
/// niet in de database -- de bijbehorende migratie is nog niet uitgevoerd --
/// dan wordt de rij opnieuw opgeslagen zonder die kolommen, zodat bijv. een
/// aanmelding niet mislukt op een nieuw, optioneel veld.
Future<void> insertWithOptionalColumns(
  String table,
  Map<String, dynamic> row, {
  required List<String> optionalColumns,
}) async {
  final client = Supabase.instance.client;
  try {
    await client.from(table).insert(row);
  } on PostgrestException catch (e) {
    final missing = optionalColumns.where((c) => e.message.contains("'$c'")).toList();
    if (e.code != 'PGRST204' || missing.isEmpty) rethrow;
    await client.from(table).insert(Map.of(row)..removeWhere((key, _) => missing.contains(key)));
  }
}

/// Werkt de rij met [id] in [table] bij met [values], met dezelfde terugval
/// voor ontbrekende [optionalColumns] als [insertWithOptionalColumns].
/// Gooit een fout als er geen rij is bijgewerkt: RLS laat een verboden update
/// stilletjes niets doen, en dat mag niet als "opgeslagen" worden gemeld.
Future<void> updateWithOptionalColumns(
  String table,
  Object id,
  Map<String, dynamic> values, {
  required List<String> optionalColumns,
}) async {
  final client = Supabase.instance.client;
  Future<List<dynamic>> run(Map<String, dynamic> v) =>
      client.from(table).update(v).eq('id', id).select('id');

  List<dynamic> updated;
  try {
    updated = await run(values);
  } on PostgrestException catch (e) {
    final missing = optionalColumns.where((c) => e.message.contains("'$c'")).toList();
    if (e.code != 'PGRST204' || missing.isEmpty) rethrow;
    updated = await run(Map.of(values)..removeWhere((key, _) => missing.contains(key)));
  }
  if (updated.isEmpty) {
    throw Exception('Niet opgeslagen: je hebt geen rechten om dit te wijzigen, of het bestaat niet meer.');
  }
}
