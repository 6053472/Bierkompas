import 'package:flutter/material.dart';
import '../home/home_page.dart';
import 'auth_storage.dart';
import 'consent_page.dart';
import 'login_page.dart';

/// Beslist bij het opstarten of de gebruiker al is ingelogd (onthouden
/// account) of eerst moet inloggen.
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
    final user = await AuthStorage.loadUser();
    if (user == null) return null;
    if (!await AuthStorage.hasCurrentConsent()) return ConsentPage(user: user);
    return const HomePage();
  }
}
