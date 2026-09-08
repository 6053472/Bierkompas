import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppUser {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;

  const AppUser({required this.id, required this.name, required this.email, this.avatarUrl});

  AppUser copyWith({String? name, String? avatarUrl}) => AppUser(
        id: id,
        name: name ?? this.name,
        email: email,
        avatarUrl: avatarUrl ?? this.avatarUrl,
      );
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class RegisterResult {
  final AppUser user;
  final bool needsEmailConfirmation;

  const RegisterResult({required this.user, required this.needsEmailConfirmation});
}

const String termsVersion = '1.0';
const String privacyVersion = '1.0';

class AuthService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<AppUser> login({required String email, required String password}) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) throw AuthException('Inloggen mislukt.');
      return _appUserFromAuth(user);
    } on AuthApiException catch (e) {
      throw AuthException(_translateAuthError(e));
    }
  }

  Future<RegisterResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );
      final user = response.user;
      if (user == null) throw AuthException('Registreren mislukt.');
      return RegisterResult(
        user: AppUser(id: user.id, name: name, email: email),
        needsEmailConfirmation: response.session == null,
      );
    } on AuthApiException catch (e) {
      throw AuthException(_translateAuthError(e));
    }
  }

  Future<void> resendConfirmationEmail(String email) async {
    try {
      await _client.auth.resend(type: OtpType.signup, email: email);
    } on AuthApiException catch (e) {
      throw AuthException(_translateAuthError(e));
    }
  }

  Future<void> saveConsent({required String userId}) async {
    try {
      await _client.from('user_consents').upsert({
        'user_id': userId,
        'terms_version': termsVersion,
        'privacy_version': privacyVersion,
        'accepted_at': DateTime.now().toIso8601String(),
        'age_confirmed': true,
        'lawful_alcohol_use': true,
        'accurate_account_data': true,
        'personal_account': true,
        'credentials_secure': true,
        'no_impersonation': true,
      }, onConflict: 'user_id,terms_version,privacy_version');
    } on PostgrestException catch (e) {
      throw AuthException(e.message);
    }
  }

  Future<AppUser> _appUserFromAuth(User user) async {
    final profile = await _client
        .from('profiles')
        .select('name, email, avatar_url')
        .eq('id', user.id)
        .maybeSingle();
    return AppUser(
      id: user.id,
      name: profile?['name'] as String? ?? '',
      email: profile?['email'] as String? ?? user.email ?? '',
      avatarUrl: profile?['avatar_url'] as String?,
    );
  }

  Future<void> updateProfile({required String userId, required String name}) async {
    try {
      await _client.from('profiles').update({'name': name}).eq('id', userId);
    } on PostgrestException catch (e) {
      throw AuthException(e.message);
    }
  }

  /// Upload een profielfoto naar Supabase Storage en slaat de publieke URL op
  /// in de profiles-tabel. Geeft de nieuwe URL terug.
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileExt,
  }) async {
    try {
      final path = '$userId/avatar.$fileExt';
      await _client.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: 'image/$fileExt'),
          );
      final url = _client.storage.from('avatars').getPublicUrl(path);
      final bustedUrl = '$url?t=${DateTime.now().millisecondsSinceEpoch}';
      await _client.from('profiles').update({'avatar_url': bustedUrl}).eq('id', userId);
      return bustedUrl;
    } on StorageException catch (e) {
      throw AuthException(e.message);
    } on PostgrestException catch (e) {
      throw AuthException(e.message);
    }
  }

  String _translateAuthError(AuthApiException e) {
    switch (e.code) {
      case 'invalid_credentials':
        return 'E-mailadres of wachtwoord is onjuist.';
      case 'email_not_confirmed':
        return 'Bevestig eerst je e-mailadres via de link die we je gestuurd hebben.';
      case 'user_already_exists':
        return 'Er bestaat al een account met dit e-mailadres.';
      case 'weak_password':
        return 'Wachtwoord is te zwak. Gebruik minimaal 8 tekens.';
      default:
        return e.message;
    }
  }
}
