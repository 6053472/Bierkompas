import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

/// Sessiebeheer via Supabase: de sessie zelf wordt automatisch lokaal bewaard
/// door supabase_flutter. Hier blijft alleen de consent-check en het uitloggen over.
class AuthStorage {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<bool> hasCurrentConsent() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final row = await _client
        .from('user_consents')
        .select('id')
        .eq('user_id', user.id)
        .eq('terms_version', termsVersion)
        .eq('privacy_version', privacyVersion)
        .maybeSingle();
    return row != null;
  }

  static Future<void> clear() async {
    // Zonder verbinding gooit signOut een fout, terwijl de lokale sessie al
    // gewist is. Dan toch doorgaan, anders blijft de gebruiker hangen.
    try {
      await _client.auth.signOut();
    } catch (_) {}
  }
}
