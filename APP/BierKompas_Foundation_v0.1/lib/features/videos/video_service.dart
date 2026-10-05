import 'package:supabase_flutter/supabase_flutter.dart';

class BierVideo {
  final int id;
  final String title;
  final String category;
  final String thumbnailUrl;
  final String videoUrl;

  const BierVideo({
    required this.id,
    required this.title,
    required this.category,
    required this.thumbnailUrl,
    required this.videoUrl,
  });

  factory BierVideo.fromJson(Map<String, dynamic> json) => BierVideo(
        id: json['id'] as int,
        title: json['title'] as String,
        category: json['category'] as String? ?? 'Tasting',
        thumbnailUrl: json['thumbnail_url'] as String,
        videoUrl: json['video_url'] as String,
      );
}

class VideoException implements Exception {
  final String message;
  VideoException(this.message);

  @override
  String toString() => message;
}

/// Leest de video-reel uit de Supabase-tabel `videos` (zie supabase/add_videos.sql).
/// Beheerders voegen video's toe via de admin-pagina; zolang die leeg is
/// toont de app een lege staat in plaats van verzonnen content.
class VideoService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<BierVideo>> fetchAll() async {
    try {
      final rows = await _client.from('videos').select().order('sort_order').order('created_at', ascending: false);
      return (rows as List).map((e) => BierVideo.fromJson(e as Map<String, dynamic>)).toList();
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205' || e.code == '42P01') return [];
      throw VideoException(e.message);
    }
  }
}
