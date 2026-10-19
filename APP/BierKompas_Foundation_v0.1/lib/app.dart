import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_gate.dart';
import 'features/auth/auth_service.dart';

class BierKompasApp extends StatefulWidget {
  const BierKompasApp({super.key});

  @override
  State<BierKompasApp> createState() => _BierKompasAppState();
}

class _BierKompasAppState extends State<BierKompasApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    // Na Google/Outlook-login komt de gebruiker in de app via de deeplink
    // terug in het al geopende inlogscherm; de AuthGate keek alleen bij het
    // opstarten naar de sessie. Daarom hier opnieuw door de AuthGate sturen.
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event != AuthChangeEvent.signedIn || !AuthService.oauthPending) return;
      AuthService.oauthPending = false;
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFF1B120A),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'BierKompas',
        theme: AppTheme.light(),
        home: const AuthGate(),
      ),
    );
  }
}
