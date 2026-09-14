import 'package:supabase_flutter/supabase_flutter.dart';

class Friend {
  final String id;
  final String name;
  final String? avatarUrl;

  const Friend({required this.id, required this.name, this.avatarUrl});
}

/// Binnengekomen, nog niet beantwoord vriendschapsverzoek.
class FriendRequest {
  final String requesterId;
  final String name;
  final String? avatarUrl;

  const FriendRequest({required this.requesterId, required this.name, this.avatarUrl});
}

enum FriendStatus { none, friends, requestSent, requestReceived }

class FriendSearchResult {
  final String id;
  final String name;
  final String? avatarUrl;
  final FriendStatus status;

  const FriendSearchResult({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.status,
  });
}

class FriendsException implements Exception {
  final String message;
  FriendsException(this.message);

  @override
  String toString() => message;
}

/// Praat met de Supabase-tabel `friend_requests` en de RPC's
/// `search_profiles`/`send_friend_request`/`respond_friend_request`.
class FriendsService {
  SupabaseClient get _client => Supabase.instance.client;

  // `profiles` heeft RLS "select own": een gewone join vanuit de app zou de
  // naam/avatar van de ánder niet mogen zien en levert dan "Onbekend" op. Deze
  // twee lijsten komen daarom uit security-definer RPC's (`list_friends` /
  // `list_incoming_friend_requests`) die dat aan de databasekant oplossen.
  Future<List<Friend>> listFriends(String userId) async {
    try {
      final rows = await _client.rpc('list_friends');
      return (rows as List).map((row) {
        return Friend(
          id: row['friend_id'] as String,
          name: row['name'] as String? ?? 'Onbekend',
          avatarUrl: row['avatar_url'] as String?,
        );
      }).toList();
    } on PostgrestException catch (e) {
      throw FriendsException(e.message);
    }
  }

  Future<List<FriendRequest>> listIncomingRequests(String userId) async {
    try {
      final rows = await _client.rpc('list_incoming_friend_requests');
      return (rows as List).map((row) {
        return FriendRequest(
          requesterId: row['requester_id'] as String,
          name: row['name'] as String? ?? 'Onbekend',
          avatarUrl: row['avatar_url'] as String?,
        );
      }).toList();
    } on PostgrestException catch (e) {
      throw FriendsException(e.message);
    }
  }

  /// Zoekt gebruikers op naam en geeft meteen de vriendschapsstatus mee,
  /// zodat de zoekpagina de juiste knop/tekst kan tonen.
  Future<List<FriendSearchResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final userId = _client.auth.currentUser?.id;
    try {
      final rows = await _client.rpc('search_profiles', params: {'p_query': trimmed});

      var friendIds = const <String>{};
      var sentIds = const <String>{};
      var receivedIds = const <String>{};
      if (userId != null) {
        final requestRows = await _client
            .from('friend_requests')
            .select('requester_id, addressee_id, status')
            .or('requester_id.eq.$userId,addressee_id.eq.$userId');
        final friends = <String>{};
        final sent = <String>{};
        final received = <String>{};
        for (final row in requestRows as List) {
          final isRequester = row['requester_id'] == userId;
          final otherId = (isRequester ? row['addressee_id'] : row['requester_id']) as String;
          if (row['status'] == 'accepted') {
            friends.add(otherId);
          } else if (isRequester) {
            sent.add(otherId);
          } else {
            received.add(otherId);
          }
        }
        friendIds = friends;
        sentIds = sent;
        receivedIds = received;
      }

      return (rows as List).map((row) {
        final id = row['id'] as String;
        final status = friendIds.contains(id)
            ? FriendStatus.friends
            : receivedIds.contains(id)
                ? FriendStatus.requestReceived
                : sentIds.contains(id)
                    ? FriendStatus.requestSent
                    : FriendStatus.none;
        return FriendSearchResult(
          id: id,
          name: row['name'] as String? ?? 'Onbekend',
          avatarUrl: row['avatar_url'] as String?,
          status: status,
        );
      }).toList();
    } on PostgrestException catch (e) {
      throw FriendsException(e.message);
    }
  }

  Future<void> sendRequest(String addresseeId) async {
    try {
      await _client.rpc('send_friend_request', params: {'p_addressee_id': addresseeId});
    } on PostgrestException catch (e) {
      throw FriendsException(e.message);
    }
  }

  Future<void> respondToRequest({required String requesterId, required bool accept}) async {
    try {
      await _client.rpc('respond_friend_request', params: {
        'p_requester_id': requesterId,
        'p_accept': accept,
      });
    } on PostgrestException catch (e) {
      throw FriendsException(e.message);
    }
  }
}
