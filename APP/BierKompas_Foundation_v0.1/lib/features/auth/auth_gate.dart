import 'package:flutter/material.dart';
import '../home/home_page.dart';
import 'auth_storage.dart';
import 'login_page.dart';

/// Beslist bij het opstarten of de gebruiker al is ingelogd (onthouden
/// account) of eerst moet inloggen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: AuthStorage.loadUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(0xFF1E1712),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFD4B28C)),
            ),
          );
        }
        return snapshot.data != null ? const HomePage() : const LoginPage();
      },
    );
  }
}
