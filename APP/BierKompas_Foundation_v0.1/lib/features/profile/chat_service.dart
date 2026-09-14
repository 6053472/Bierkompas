import 'package:supabase_flutter/supabase_flutter.dart';

enum MessageType { text, beerShare, eventInvite }

MessageType _typeFromString(String? value) {
  switch (value) {
    case 'beer_share':
      return MessageType.beerShare;
    case 'event_invite':
      return MessageType.eventInvite;
    default:
      return MessageType.text;
  }
}

String _typeToString(MessageType type) {
  switch (type) {
    case MessageType.beerShare:
      return 'beer_share';
    case MessageType.eventInvite:
      return 'event_invite';
    case MessageType.text:
      return 'text';
  }
}

class ChatMessage {
  final int id;
  final String senderId;
  final String body;
  final MessageType type;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime? readAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.type,
    this.metadata,
    required this.createdAt,
    this.readAt,
  });

  factory ChatMessage.fromRow(Map<String, dynamic> row) => ChatMessage(
        id: row['id'] as int,
        senderId: row['sender_id'] as String,
        body: row['body'] as String? ?? '',
        type: _typeFromString(row['message_type'] as String?),
        metadata: row['metadata'] as Map<String, dynamic>?,
        createdAt: DateTime.parse(row['created_at'] as String),
        readAt: row['read_at'] != null ? DateTime.parse(row['read_at'] as String) : null,
      );
}

class ChatException implements Exception {
  final String message;
  ChatException(this.message);

  @override
  String toString() => message;
}

/// Praat met de Supabase-tabel `messages` en de RPC's `send_message`/
/// `mark_messages_read`.
class ChatService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<ChatMessage>> listMessages(String otherUserId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    try {
      final rows = await _client
          .from('messages')
          .select()
          .or('and(sender_id.eq.$userId,receiver_id.eq.$otherUserId),'
              'and(sender_id.eq.$otherUserId,receiver_id.eq.$userId)')
          .order('created_at', ascending: true);
      return (rows as List).map((row) => ChatMessage.fromRow(row as Map<String, dynamic>)).toList();
    } on PostgrestException catch (e) {
      throw ChatException(e.message);
    }
  }

  Future<void> sendMessage({
    required String receiverId,
    required String body,
    MessageType type = MessageType.text,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _client.rpc('send_message', params: {
        'p_receiver_id': receiverId,
        'p_body': body,
        'p_message_type': _typeToString(type),
        if (metadata != null) 'p_metadata': metadata,
      });
    } on PostgrestException catch (e) {
      throw ChatException(e.message);
    }
  }

  Future<void> markRead(String otherUserId) async {
    try {
      await _client.rpc('mark_messages_read', params: {'p_other_id': otherUserId});
    } on PostgrestException catch (e) {
      throw ChatException(e.message);
    }
  }
}
