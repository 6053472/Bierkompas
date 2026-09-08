import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/api_config.dart';

class AppUser {
  final int id;
  final String name;
  final String email;

  const AppUser({required this.id, required this.name, required this.email});

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as int,
        name: json['name'] as String,
        email: json['email'] as String,
      );
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

/// Testaccount waarmee de app te gebruiken is zolang er nog geen hosting/backend is.
/// Zet ApiConfig.baseUrl om automatisch op de echte backend over te schakelen.
const String _testEmail = 'test@bierkompas.nl';
const String _testPassword = 'test1234';
const String termsVersion = '1.0';
const String privacyVersion = '1.0';

class AuthService {
  Future<AppUser> login({required String email, required String password}) async {
    if (!ApiConfig.isConfigured) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (email.trim().toLowerCase() == _testEmail && password == _testPassword) {
        return const AppUser(id: 0, name: 'Test Gebruiker', email: _testEmail);
      }
      throw AuthException(
        'Nog geen backend gekoppeld. Gebruik het testaccount: $_testEmail / $_testPassword',
      );
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/login.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || body['success'] != true) {
      throw AuthException(body['error'] as String? ?? 'Inloggen mislukt.');
    }
    return AppUser.fromJson(body['user'] as Map<String, dynamic>);
  }

  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    if (!ApiConfig.isConfigured) {
      throw AuthException('Registreren is pas mogelijk zodra de backend gekoppeld is.');
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/register.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || body['success'] != true) {
      throw AuthException(body['error'] as String? ?? 'Registreren mislukt.');
    }
    return AppUser.fromJson(body['user'] as Map<String, dynamic>);
  }

  Future<void> saveConsent({required int userId}) async {
    if (!ApiConfig.isConfigured) return;

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/consent.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'terms_version': termsVersion,
        'privacy_version': privacyVersion,
        'age_confirmed': true,
        'lawful_alcohol_use': true,
        'accurate_account_data': true,
        'personal_account': true,
        'credentials_secure': true,
        'no_impersonation': true,
      }),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || body['success'] != true) {
      throw AuthException(body['error'] as String? ?? 'Akkoord opslaan mislukt.');
    }
  }
}
