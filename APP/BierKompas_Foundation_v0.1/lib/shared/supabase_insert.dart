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
