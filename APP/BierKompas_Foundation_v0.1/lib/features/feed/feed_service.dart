import 'package:supabase_flutter/supabase_flutter.dart';
import 'feed_samples.dart';

/// Soort content in de feed; komt uit de kolom `item_type` van de view `feed`.
enum FeedItemType { review, tip, weetje, evenement }

class FeedItem {
  /// Uniek over alle bronnen van de feed, bijv. `item-12` of `event-3`.
  final String key;
  final FeedItemType type;
  final String title;
  final String body;
  final String? imageUrl;
  final String? author;
  final double? rating;
  final DateTime? eventStart;
  final String? eventLocation;
  final DateTime createdAt;

  const FeedItem({
    required this.key,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.imageUrl,
    this.author,
    this.rating,
    this.eventStart,
    this.eventLocation,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) => FeedItem(
        key: json['feed_key'] as String,
        type: FeedItemType.values.firstWhere(
          (t) => t.name == json['item_type'],
          orElse: () => FeedItemType.weetje,
        ),
        title: json['title'] as String,
        body: json['body'] as String,
        imageUrl: json['image_url'] as String?,
        author: json['author'] as String?,
        rating: (json['rating'] as num?)?.toDouble(),
        eventStart: json['event_start'] == null ? null : DateTime.parse(json['event_start'] as String),
        eventLocation: json['event_location'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  /// Hoe dit item in de tabel `favorites` wordt opgeslagen (`item_type` en `item_id`).
  String get favoriteType => type == FeedItemType.evenement ? 'event' : 'feed_item';
  int get favoriteId => int.parse(key.substring(key.indexOf('-') + 1));

  /// De feed_key die bij een favoriet hoort, of null als die favoriet geen feed-item is.
  static String? keyForFavorite(String itemType, int itemId) => switch (itemType) {
        'feed_item' => 'item-$itemId',
        'event' => 'event-$itemId',
        _ => null,
      };
}

class FeedException implements Exception {
  final String message;
  FeedException(this.message);

  @override
  String toString() => message;
}

/// Leest de Ontdek-feed in batches uit de Supabase-view `feed` (zie supabase/add_feed.sql).
class FeedService {
  static const pageSize = 15;

  SupabaseClient get _client => Supabase.instance.client;

  /// Haalt [pageSize] items op vanaf [offset]. Een kortere lijst betekent: einde van de feed.
  Future<List<FeedItem>> fetchPage(int offset) async {
    try {
      final rows = await _client
          .from('feed')
          .select()
          .order('created_at', ascending: false)
          .order('feed_key')
          .range(offset, offset + pageSize - 1);
      return rows.map(FeedItem.fromJson).toList();
    } on PostgrestException catch (e) {
      if (_isMissingView(e)) return _samplePage(offset);
      throw FeedException(e.message);
    }
  }

  /// Haalt specifieke items op, bijvoorbeeld je gelikete feed-berichten; nieuwste eerst.
  Future<List<FeedItem>> fetchByKeys(List<String> keys) async {
    try {
      final rows = await _client
          .from('feed')
          .select()
          .inFilter('feed_key', keys)
          .order('created_at', ascending: false);
      return rows.map(FeedItem.fromJson).toList();
    } on PostgrestException catch (e) {
      if (_isMissingView(e)) return sampleFeedItems.where((i) => keys.contains(i.key)).toList();
      throw FeedException(e.message);
    }
  }

  // Zolang supabase/add_feed.sql niet is uitgevoerd bestaat de view nog niet;
  // dan toont de app de voorbeeldcontent uit feed_samples.dart.
  static bool _isMissingView(PostgrestException e) => e.code == 'PGRST205' || e.code == '42P01';

  Future<List<FeedItem>> _samplePage(int offset) async {
    // Korte vertraging, zodat het laden van een nieuwe batch ook met voorbeelddata zichtbaar is.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return sampleFeedItems.skip(offset).take(pageSize).toList();
  }
}
