import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/api_config.dart';

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

/// Praat met favorites_list.php / favorites_add.php / favorites_remove.php.
/// Nog niet gekoppeld aan een schermonderdeel, want de bar/bier-datamodellen
/// (waar item_id naar verwijst) bestaan nog niet. Klaar om te gebruiken
/// zodra de backend live is en die modellen er zijn.
class FavoritesService {
  Future<List<FavoriteItem>> list(int userId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/favorites_list.php?user_id=$userId'),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || body['success'] != true) {
      throw FavoritesException(body['error'] as String? ?? 'Favorieten ophalen mislukt.');
    }
    return (body['favorites'] as List)
        .map((e) => FavoriteItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> add({required int userId, required String itemType, required int itemId}) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/favorites_add.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'item_type': itemType, 'item_id': itemId}),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || body['success'] != true) {
      throw FavoritesException(body['error'] as String? ?? 'Toevoegen aan favorieten mislukt.');
    }
  }

  Future<void> remove({required int userId, required String itemType, required int itemId}) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/favorites_remove.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'item_type': itemType, 'item_id': itemId}),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || body['success'] != true) {
      throw FavoritesException(body['error'] as String? ?? 'Verwijderen uit favorieten mislukt.');
    }
  }
}
