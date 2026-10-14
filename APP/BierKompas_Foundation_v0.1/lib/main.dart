import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';
import 'features/books/books_service.dart';
import 'features/favorites/beers_service.dart';
import 'features/map/breweries_service.dart';
import 'features/music/music_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  // Door beheerders toegevoegde bieren, nummers en boeken; elk mislukt stil als
  // de bijbehorende migratie nog niet is gedraaid.
  await Future.wait([loadCustomBeers(), loadCustomSongs(), loadCustomBooks(), loadBreweries()]);

  runApp(const BierKompasApp());
}

