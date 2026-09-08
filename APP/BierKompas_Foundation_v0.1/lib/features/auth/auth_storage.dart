import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

/// Onthoudt het ingelogde account lokaal op het toestel, zodat de gebruiker
/// niet elke keer opnieuw hoeft in te loggen.
class AuthStorage {
  static const _key = 'bierkompas_user';
  static const _consentKey = 'bierkompas_consent_version';

  static Future<void> saveUser(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({'id': user.id, 'name': user.name, 'email': user.email}),
    );
  }

  static Future<AppUser?> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_key),
      prefs.remove(_consentKey),
    ]);
  }

  static Future<bool> hasCurrentConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_consentKey) == '$termsVersion:$privacyVersion';
  }

  static Future<void> saveConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_consentKey, '$termsVersion:$privacyVersion');
  }
}
