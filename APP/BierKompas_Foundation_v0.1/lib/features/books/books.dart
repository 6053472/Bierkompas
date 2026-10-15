import 'package:shared_preferences/shared_preferences.dart';

enum BookStatus { toRead, reading, finished }

extension BookStatusLabel on BookStatus {
  String get label {
    switch (this) {
      case BookStatus.toRead:
        return 'Nog te lezen';
      case BookStatus.reading:
        return 'Aan het lezen';
      case BookStatus.finished:
        return 'Voltooid';
    }
  }
}

class Book {
  final String id;
  final String title;
  final String author;
  final String? subtitle;
  final String coverAsset;

  /// Cover-URL van een door een beheerder toegevoegd boek (zie
  /// supabase/add_admin_content_management.sql); de vaste boeken gebruiken [coverAsset].
  final String? coverUrl;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.coverAsset,
    this.subtitle,
    this.coverUrl,
  });
}

// Geen `const`: boeken die een beheerder via de admin-pagina toevoegt worden
// bij het opstarten aan deze lijst toegevoegd (zie books_service.dart).
/// De boeken uit de Bierkompas-bibliotheek (covers: assets/books/).
final List<Book> books = [
  Book(
    id: 'bierwandelboek',
    title: 'Het grote Nederlandse Bierwandelboek',
    author: 'Erik van der Waard',
    subtitle: 'Wandelen en genieten van het beste bier van eigen bodem',
    coverAsset: 'assets/books/bierwandelboek.png',
  ),
  Book(
    id: 'bier_bbqboek',
    title: 'Het ultieme Bier- & BBQboek',
    author: 'Jeroen Hazebroek',
    coverAsset: 'assets/books/bier_bbqboek.png',
  ),
  Book(
    id: 'belgische_bierstijlen',
    title: 'Iconische Belgische Bierstijlen',
    author: 'Ben Vinken',
    coverAsset: 'assets/books/belgische_bierstijlen.png',
  ),
];

/// Bewaart per boek de leesstatus van de gebruiker op dit toestel
/// (SharedPreferences). Boeken zonder status staan als "Nog te lezen" in de lijst.
class BookStatusStore {
  static String _key(String bookId) => 'book_status_$bookId';

  Future<Map<String, BookStatus>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, BookStatus>{};
    for (final book in books) {
      final index = prefs.getInt(_key(book.id));
      if (index != null && index >= 0 && index < BookStatus.values.length) {
        result[book.id] = BookStatus.values[index];
      }
    }
    return result;
  }

  Future<void> save(String bookId, BookStatus status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key(bookId), status.index);
  }
}
