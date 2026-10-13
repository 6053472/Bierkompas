import 'package:supabase_flutter/supabase_flutter.dart';

/// Waar een video vandaan komt. Externe video's (YouTube, TikTok, Instagram)
/// worden alleen als link/ID opgeslagen en via de officiële embed-speler van
/// dat platform getoond; eigen video's worden native afgespeeld.
enum VideoSource { hosted, youtube, tiktok, instagram }

VideoSource _sourceFromString(String? value) => VideoSource.values.firstWhere(
      (s) => s.name == value,
      orElse: () => VideoSource.hosted,
    );

class BierVideo {
  final int id;
  final String title;
  final String category;
  final String? thumbnailUrl;
  final String videoUrl;
  final VideoSource source;

  /// YouTube: video-ID. TikTok: numeriek video-ID. Instagram: "reel/CODE" of
  /// "p/CODE". Leeg bij eigen video's.
  final String? externalId;

  const BierVideo({
    required this.id,
    required this.title,
    required this.category,
    required this.videoUrl,
    this.thumbnailUrl,
    this.source = VideoSource.hosted,
    this.externalId,
  });

  factory BierVideo.fromJson(Map<String, dynamic> json) => BierVideo(
        id: json['id'] as int,
        title: json['title'] as String,
        category: json['category'] as String? ?? 'Tasting',
        thumbnailUrl: json['thumbnail_url'] as String?,
        videoUrl: json['video_url'] as String,
        source: _sourceFromString(json['source'] as String?),
        externalId: json['external_id'] as String?,
      );

  bool get isHosted => source == VideoSource.hosted;

  /// Afbeelding om te tonen voordat de video speelt. Voor YouTube kan die
  /// altijd worden afgeleid uit het ID; voor TikTok/Instagram bestaat zonder
  /// API geen thumbnail, dan blijft het bij wat de beheerder heeft ingevuld.
  String? get previewImage {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) return thumbnailUrl;
    if (source == VideoSource.youtube && externalId != null) {
      return 'https://img.youtube.com/vi/$externalId/hqdefault.jpg';
    }
    return null;
  }

  /// Officiële embed-URL van TikTok of Instagram (voor in een iframe/WebView).
  String? get embedUrl {
    final id = externalId;
    if (id == null || id.isEmpty) return null;
    switch (source) {
      case VideoSource.tiktok:
        return 'https://www.tiktok.com/embed/v2/$id';
      case VideoSource.instagram:
        return 'https://www.instagram.com/$id/embed';
      case VideoSource.youtube:
      case VideoSource.hosted:
        return null;
    }
  }
}

class VideoException implements Exception {
  final String message;
  VideoException(this.message);

  @override
  String toString() => message;
}

/// Leest de video-reel uit de Supabase-tabel `videos` (zie supabase/add_videos.sql
/// en supabase/add_video_reel.sql), in pagina's zodat de reel oneindig door kan
/// scrollen zonder alles in één keer te laden. Beheerders voegen video's toe via
/// de admin-pagina; zolang die leeg is toont de app een lege staat in plaats van
/// verzonnen content.
class VideoService {
  static const pageSize = 8;

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<BierVideo>> fetchPage(int offset) async {
    try {
      final rows = await _client
          .from('videos')
          .select()
          .order('sort_order')
          .order('created_at', ascending: false)
          .order('id')
          .range(offset, offset + pageSize - 1);
      return (rows as List).map((e) => BierVideo.fromJson(e as Map<String, dynamic>)).toList();
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205' || e.code == '42P01') return [];
      throw VideoException(e.message);
    }
  }
}
