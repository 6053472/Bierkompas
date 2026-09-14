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

  static Map<String, dynamic>? _profile(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is List && value.isNotEmpty) return value.first as Map<String, dynamic>;
    return null;
  }

  Future<List<Friend>> listFriends(String userId) async {
    try {
      final rows = await _client
          .from('friend_requests')
          .select(
            'requester_id, addressee_id, '
            'requester:profiles!requester_id(name, avatar_url), '
            'addressee:profiles!addressee_id(name, avatar_url)',
          )
          .eq('status', 'accepted')
          .or('requester_id.eq.$userId,addressee_id.eq.$userId');

      return (rows as List).map((row) {
        final isRequester = row['requester_id'] == userId;
        final otherId = (isRequester ? row['addressee_id'] : row['requester_id']) as String;
        final otherProfile = _profile(isRequester ? row['addressee'] : row['requester']);
        return Friend(
          id: otherId,
          name: otherProfile?['name'] as String? ?? 'Onbekend',
          avatarUrl: otherProfile?['avatar_url'] as String?,
        );
      }).toList();
    } on PostgrestException catch (e) {
      throw FriendsException(e.message);
    }
  }

  Future<List<FriendRequest>> listIncomingRequests(String userId) async {
    try {
      final rows = await _client
          .from('friend_requests')
          .select('requester_id, requester:profiles!requester_id(name, avatar_url)')
          .eq('addressee_id', userId)
          .eq('status', 'pending');

      return (rows as List).map((row) {
        final profile = _profile(row['requester']);
        return FriendRequest(
          requesterId: row['requester_id'] as String,
          name: profile?['name'] as String? ?? 'Onbekend',
          avatarUrl: profile?['avatar_url'] as String?,
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
