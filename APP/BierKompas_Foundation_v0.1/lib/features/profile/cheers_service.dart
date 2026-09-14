import 'package:supabase_flutter/supabase_flutter.dart';

class Cheer {
  final int id;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;

  /// True als dit een "Proost terug" is op een proost die ík eerder stuurde.
  /// Zo'n reactie toont het rustige bevestigingsscherm in plaats van weer een
  /// "Proost terug"-knop, om een oneindige heen-en-weer keten te voorkomen.
  final bool isReply;

  const Cheer({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    this.isReply = false,
  });
}

class CheersException implements Exception {
  final String message;
  CheersException(this.message);

  @override
  String toString() => message;
}

/// Praat met de Supabase-tabel `cheers` en de RPC's `send_cheer`/
/// `list_unseen_cheers`/`mark_cheer_seen`.
class CheersService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<void> sendCheer(String receiverId, {int? replyToId}) async {
    try {
      await _client.rpc('send_cheer', params: {
        'p_receiver_id': receiverId,
        if (replyToId != null) 'p_reply_to_id': replyToId,
      });
    } on PostgrestException catch (e) {
      throw CheersException(e.message);
    }
  }

  Future<List<Cheer>> listUnseen() async {
    try {
      final rows = await _client.rpc('list_unseen_cheers');
      return (rows as List)
          .map((row) => Cheer(
                id: row['id'] as int,
                senderId: row['sender_id'] as String,
                senderName: row['name'] as String? ?? 'Onbekend',
                senderAvatarUrl: row['avatar_url'] as String?,
                isReply: row['is_reply'] as bool? ?? false,
              ))
          .toList();
    } on PostgrestException catch (e) {
      throw CheersException(e.message);
    }
  }

  Future<void> markSeen(int cheerId) async {
    try {
      await _client.rpc('mark_cheer_seen', params: {'p_cheer_id': cheerId});
    } on PostgrestException catch (e) {
      throw CheersException(e.message);
    }
  }
}
