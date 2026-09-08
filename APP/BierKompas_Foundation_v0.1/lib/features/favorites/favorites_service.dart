import 'package:supabase_flutter/supabase_flutter.dart';

class FavoriteItem {
  final int id;
  final String itemType;
  final int itemId;

  const FavoriteItem({required this.id, required this.itemType, required this.itemId});

  factory FavoriteItem.fromJson(Map<String, dynamic> json) => FavoriteItem(
        id: json['id'] as int,
        itemType: json['item_type'] as String,
        itemId: json['item_id'] as int,
      );
}

class FavoritesException implements Exception {
  final String message;
  FavoritesException(this.message);

  @override
  String toString() => message;
}

/// Praat met de Supabase-tabel `favorites`.
/// Nog niet gekoppeld aan een schermonderdeel, want de bar/bier-datamodellen
/// (waar item_id naar verwijst) bestaan nog niet.
class FavoritesService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<FavoriteItem>> list(String userId) async {
    try {
      final rows = await _client.from('favorites').select().eq('user_id', userId);
      return (rows as List)
          .map((e) => FavoriteItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw FavoritesException(e.message);
    }
  }

  Future<void> add({required String userId, required String itemType, required int itemId}) async {
    try {
      await _client.from('favorites').insert({
        'user_id': userId,
        'item_type': itemType,
        'item_id': itemId,
      });
    } on PostgrestException catch (e) {
      throw FavoritesException(e.message);
    }
  }

  Future<void> remove({required String userId, required String itemType, required int itemId}) async {
    try {
      await _client
          .from('favorites')
          .delete()
          .eq('user_id', userId)
          .eq('item_type', itemType)
          .eq('item_id', itemId);
    } on PostgrestException catch (e) {
      throw FavoritesException(e.message);
    }
  }
}
