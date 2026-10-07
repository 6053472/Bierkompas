import 'package:supabase_flutter/supabase_flutter.dart';

class AppNotification {
  final int id;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as int,
        title: json['title'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        readAt: json['read_at'] == null ? null : DateTime.parse(json['read_at'] as String),
      );
}

class NotificationsException implements Exception {
  final String message;
  NotificationsException(this.message);

  @override
  String toString() => message;
}

/// Berichtencentrum: automatische meldingen (evenement goedgekeurd/afgewezen)
/// en berichten van een beheerder. Zie supabase/add_notifications.sql.
class NotificationsService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<AppNotification>> fetchAll(String userId) async {
    try {
      final rows = await _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (rows as List).map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205' || e.code == '42P01') return [];
      throw NotificationsException(e.message);
    }
  }

  Future<int> fetchUnreadCount(String userId) async {
    try {
      final rows = await _client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .filter('read_at', 'is', null);
      return (rows as List).length;
    } on PostgrestException catch (_) {
      return 0;
    }
  }

  Future<void> markRead(int id) async {
    try {
      await _client.from('notifications').update({'read_at': DateTime.now().toIso8601String()}).eq('id', id);
    } on PostgrestException catch (e) {
      throw NotificationsException(e.message);
    }
  }
}
