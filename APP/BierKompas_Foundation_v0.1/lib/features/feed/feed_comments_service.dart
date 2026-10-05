import 'package:supabase_flutter/supabase_flutter.dart';

class FeedComment {
  final int id;
  final int feedItemId;
  final String? userId;
  final String author;
  final String? avatarUrl;
  final String body;
  final double? rating;
  final DateTime createdAt;

  const FeedComment({
    required this.id,
    required this.feedItemId,
    required this.author,
    required this.body,
    required this.createdAt,
    this.userId,
    this.avatarUrl,
    this.rating,
  });

  factory FeedComment.fromJson(Map<String, dynamic> json) => FeedComment(
        id: json['id'] as int,
        feedItemId: json['feed_item_id'] as int,
        userId: json['user_id'] as String?,
        author: json['author'] as String? ?? 'Bierliefhebber',
        avatarUrl: json['avatar_url'] as String?,
        body: json['body'] as String,
        rating: (json['rating'] as num?)?.toDouble(),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class FeedCommentException implements Exception {
  final String message;
  FeedCommentException(this.message);

  @override
  String toString() => message;
}

/// Reacties (en proefnotities-als-reactie, met een optionele beoordeling) op
/// een item in de Ontdek-feed. Zie supabase/add_feed_comments.sql.
class FeedCommentsService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<FeedComment>> fetchComments(int feedItemId) async {
    try {
      final rows = await _client
          .from('feed_comments')
          .select()
          .eq('feed_item_id', feedItemId)
          .order('created_at');
      return (rows as List).map((e) => FeedComment.fromJson(e as Map<String, dynamic>)).toList();
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205' || e.code == '42P01') return [];
      throw FeedCommentException(e.message);
    }
  }

  /// Plaatst een reactie. [rating] is alleen zinvol bij een mini-review
  /// (proeverij) en kent bij een hoog gemiddelde de 'Super Model'-badge toe
  /// aan de maker van die proeverij (zie supabase/add_feed_comments.sql).
  Future<void> postComment({
    required int feedItemId,
    required String body,
    double? rating,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw FeedCommentException('Je bent niet ingelogd.');
    try {
      await _client.rpc('post_feed_comment', params: {
        'p_feed_item_id': feedItemId,
        'p_body': body,
        if (rating != null) 'p_rating': rating,
      });
    } on PostgrestException catch (e) {
      throw FeedCommentException(e.message);
    }
  }

  Future<void> deleteComment(int commentId) async {
    try {
      await _client.from('feed_comments').delete().eq('id', commentId);
    } on PostgrestException catch (e) {
      throw FeedCommentException(e.message);
    }
  }
}
