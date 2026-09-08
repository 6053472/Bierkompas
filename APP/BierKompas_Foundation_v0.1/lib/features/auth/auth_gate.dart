import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../home/home_page.dart';
import 'auth_service.dart';
import 'auth_storage.dart';
import 'consent_page.dart';
import 'login_page.dart';

/// Beslist bij het opstarten of de gebruiker al is ingelogd (Supabase-sessie
/// aanwezig) of eerst moet inloggen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _loadDestination(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(0xFF1E1712),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFD4B28C)),
            ),
          );
        }
        return snapshot.data ?? const LoginPage();
      },
    );
  }

  Future<Widget?> _loadDestination() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    if (!await AuthStorage.hasCurrentConsent()) {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('name, email')
          .eq('id', user.id)
          .maybeSingle();
      final appUser = AppUser(
        id: user.id,
        name: profile?['name'] as String? ?? '',
        email: profile?['email'] as String? ?? user.email ?? '',
      );
      return ConsentPage(user: appUser);
    }
    return const HomePage();
  }
}
