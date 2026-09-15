import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../favorites/beers.dart' show beerItemType;
import '../map/breweries.dart' show breweryItemType;
import 'feed_samples.dart';

/// Soort content in de feed; komt uit de kolom `item_type` van de view `feed`.
enum FeedItemType { review, tip, weetje, brouwerij, evenement, post }

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

  /// Het bier waar deze post over gaat (id uit beers.dart), of null.
  final int? beerId;

  /// De brouwerij waar deze post over gaat (id uit breweries.dart), of null.
  final int? breweryId;

  /// Wie deze post plaatste (alleen gezet bij `type == post`), voor "eigen post" checks.
  final String? authorId;
  final String? authorAvatarUrl;

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
    this.beerId,
    this.breweryId,
    this.authorId,
    this.authorAvatarUrl,
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
        beerId: (json['beer_id'] as num?)?.toInt(),
        breweryId: (json['brewery_id'] as num?)?.toInt(),
        authorId: json['user_id'] as String?,
        authorAvatarUrl: json['avatar_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  /// Hoe een like op deze post in de tabel `favorites` wordt opgeslagen. Een post over
  /// een bier of brouwerij liket dat bier of die brouwerij; anders wordt de post zelf bewaard.
  String get favoriteType {
    if (beerId != null) return beerItemType;
    if (breweryId != null) return breweryItemType;
    return type == FeedItemType.evenement ? 'event' : 'feed_item';
  }

  int get favoriteId => beerId ?? breweryId ?? int.parse(key.substring(key.indexOf('-') + 1));

  /// Sleutel voor een set met likes, bijv. `beer:5` of `feed_item:12`.
  static String favoriteKeyOf(String itemType, int itemId) => '$itemType:$itemId';

  /// De feed_key die bij een gelikete post hoort, of null als de favoriet geen post is
  /// (maar bijvoorbeeld een bier of brouwerij).
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

  /// Haalt specifieke items op, bijvoorbeeld je gelikete posts; nieuwste eerst.
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

  /// Plaatst een eigen post in de feed. [title] mag leeg zijn (dan wordt de
  /// tekst zelf als titel gebruikt); de post verschijnt bovenaan bij `Sanne`/
  /// andere gebruikers omdat de feed op `created_at` sorteert.
  Future<FeedItem> createPost({
    required String body,
    String? title,
    String? imageUrl,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw FeedException('Je bent niet ingelogd.');
    try {
      final profile = await _client
          .from('profiles')
          .select('name, avatar_url')
          .eq('id', user.id)
          .maybeSingle();
      final authorName = profile?['name'] as String? ?? 'Bierliefhebber';
      final avatarUrl = profile?['avatar_url'] as String?;
      final row = await _client
          .from('feed_items')
          .insert({
            'item_type': 'post',
            'title': (title == null || title.trim().isEmpty)
                ? (body.length > 60 ? '${body.substring(0, 60)}…' : body)
                : title.trim(),
            'body': body,
            'image_url': imageUrl,
            'author': authorName,
            'user_id': user.id,
            'avatar_url': avatarUrl,
          })
          .select()
          .single();
      // De insert leest uit feed_items, niet uit de view `feed`; feed_key
      // hier zelf samenstellen zodat het resultaat meteen bruikbaar is.
      return FeedItem.fromJson({...row, 'feed_key': 'item-${row['id']}'});
    } on PostgrestException catch (e) {
      throw FeedException(e.message);
    }
  }

  /// Verwijdert een eigen post. [feedKey] is bijv. `item-42`; RLS zorgt dat
  /// dit alleen lukt als de post ook echt van de ingelogde gebruiker is.
  Future<void> deletePost(String feedKey) async {
    final id = int.tryParse(feedKey.split('-').last);
    if (id == null) throw FeedException('Ongeldige post.');
    try {
      await _client.from('feed_items').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw FeedException(e.message);
    }
  }

  /// Upload een foto bij een post naar Supabase Storage en geeft de publieke URL terug.
  Future<String> uploadImage({required Uint8List bytes, required String fileExt}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw FeedException('Je bent niet ingelogd.');
    try {
      final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      await _client.storage.from('feed-images').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$fileExt'),
          );
      return _client.storage.from('feed-images').getPublicUrl(path);
    } on StorageException catch (e) {
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
