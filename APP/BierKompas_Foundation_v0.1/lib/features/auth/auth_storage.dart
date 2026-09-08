import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';

/// Onthoudt het ingelogde account lokaal op het toestel, zodat de gebruiker
/// niet elke keer opnieuw hoeft in te loggen.
class AuthStorage {
  static const _key = 'bierkompas_user';

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
    await prefs.remove(_key);
  }
}
