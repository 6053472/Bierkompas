import 'package:supabase_flutter/supabase_flutter.dart';

/// Eigen telefoonnummer plus de keuze of bevestigde vrienden het mogen zien.
class OwnPhone {
  final String phone;
  final bool shareWithFriends;

  const OwnPhone({required this.phone, required this.shareWithFriends});
}

class FriendPhoneException implements Exception {
  final String message;
  const FriendPhoneException(this.message);

  @override
  String toString() => message;
}

/// Regelt "Bellen" bij een Biervriend: je eigen nummer opslaan en het nummer
/// van een vriend ophalen, alleen als die het zelf deelt. Zie
/// supabase/add_friend_phone.sql.
class FriendPhoneService {
  SupabaseClient get _client => Supabase.instance.client;

  /// Je eigen nummer, of null als je er (nog) geen hebt ingevuld.
  Future<OwnPhone?> fetchOwn(String userId) async {
    try {
      final row = await _client
          .from('friend_phones')
          .select('phone, share_with_friends')
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return null;
      return OwnPhone(
        phone: row['phone'] as String,
        shareWithFriends: row['share_with_friends'] as bool? ?? false,
      );
    } on PostgrestException {
      return null;
    }
  }

  /// Slaat je nummer op; een leeg nummer verwijdert het.
  Future<void> saveOwn({
    required String userId,
    required String phone,
    required bool shareWithFriends,
  }) async {
    try {
      if (phone.isEmpty) {
        await _client.from('friend_phones').delete().eq('user_id', userId);
        return;
      }
      await _client.from('friend_phones').upsert({
        'user_id': userId,
        'phone': phone,
        'share_with_friends': shareWithFriends,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } on PostgrestException catch (e) {
      throw FriendPhoneException('Telefoonnummer opslaan mislukt: ${e.message}');
    }
  }

  /// Het nummer van een vriend, of null als die het niet deelt.
  Future<String?> friendPhone(String friendId) async {
    try {
      final result = await _client.rpc('friend_phone', params: {'p_friend_id': friendId});
      final phone = result as String?;
      return (phone == null || phone.isEmpty) ? null : phone;
    } on PostgrestException catch (e) {
      throw FriendPhoneException('Telefoonnummer ophalen mislukt: ${e.message}');
    }
  }
}
