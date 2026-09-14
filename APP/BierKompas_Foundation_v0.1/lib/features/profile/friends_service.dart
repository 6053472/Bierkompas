import 'package:supabase_flutter/supabase_flutter.dart';

class Friend {
  final String id;
  final String name;
  final String? avatarUrl;

  const Friend({required this.id, required this.name, this.avatarUrl});
}

class FriendSearchResult {
  final String id;
  final String name;
  final String? avatarUrl;
  final bool alreadyFriend;

  const FriendSearchResult({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.alreadyFriend,
  });
}

class FriendsException implements Exception {
  final String message;
  FriendsException(this.message);

  @override
  String toString() => message;
}

/// Praat met de Supabase-tabel `friendships` en de RPC's `search_profiles`/`add_friend`.
class FriendsService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<Friend>> list(String userId) async {
    try {
      final rows = await _client
          .from('friendships')
          .select('friend_id, profiles!friend_id(name, avatar_url)')
          .eq('user_id', userId);
      return (rows as List).map((row) {
        final profile = row['profiles'] as Map<String, dynamic>?;
        return Friend(
          id: row['friend_id'] as String,
          name: profile?['name'] as String? ?? 'Onbekend',
          avatarUrl: profile?['avatar_url'] as String?,
        );
      }).toList();
    } on PostgrestException catch (e) {
      throw FriendsException(e.message);
    }
  }

  /// Zoekt gebruikers op naam. Geeft ook aan wie er al bevriend mee is,
  /// zodat de "Toevoegen"-knop dat kan tonen.
  Future<List<FriendSearchResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final userId = _client.auth.currentUser?.id;
    try {
      final rows = await _client.rpc('search_profiles', params: {'p_query': trimmed});
      final currentFriendIds = userId == null
          ? <String>{}
          : (await list(userId)).map((f) => f.id).toSet();
      return (rows as List).map((row) {
        final id = row['id'] as String;
        return FriendSearchResult(
          id: id,
          name: row['name'] as String? ?? 'Onbekend',
          avatarUrl: row['avatar_url'] as String?,
          alreadyFriend: currentFriendIds.contains(id),
        );
      }).toList();
    } on PostgrestException catch (e) {
      throw FriendsException(e.message);
    }
  }

  Future<void> addFriend(String friendId) async {
    try {
      await _client.rpc('add_friend', params: {'p_friend_id': friendId});
    } on PostgrestException catch (e) {
      throw FriendsException(e.message);
    }
  }
}
