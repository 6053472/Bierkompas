import 'package:supabase_flutter/supabase_flutter.dart';

class TastingNote {
  final int id;
  final int? beerId;
  final String beerName;
  final String note;
  final int rating;
  final DateTime createdAt;

  const TastingNote({
    required this.id,
    required this.beerName,
    required this.note,
    required this.rating,
    required this.createdAt,
    this.beerId,
  });

  factory TastingNote.fromJson(Map<String, dynamic> json) => TastingNote(
        id: json['id'] as int,
        beerId: (json['beer_id'] as num?)?.toInt(),
        beerName: json['beer_name'] as String,
        note: json['note'] as String,
        rating: json['rating'] as int,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class TastingNoteException implements Exception {
  final String message;
  TastingNoteException(this.message);

  @override
  String toString() => message;
}

/// Praat met de Supabase-tabel `tasting_notes` (zie supabase/add_tasting_notes.sql).
class TastingNotesService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<TastingNote>> fetchAll(String userId) async {
    try {
      final rows = await _client
          .from('tasting_notes')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((r) => TastingNote.fromJson(r as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw TastingNoteException(e.message);
    }
  }

  Future<TastingNote> create({
    required String beerName,
    required String note,
    required int rating,
    int? beerId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw TastingNoteException('Je bent niet ingelogd.');
    try {
      final row = await _client
          .from('tasting_notes')
          .insert({
            'user_id': user.id,
            'beer_id': beerId,
            'beer_name': beerName,
            'note': note,
            'rating': rating,
          })
          .select()
          .single();
      return TastingNote.fromJson(row);
    } on PostgrestException catch (e) {
      throw TastingNoteException(e.message);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _client.from('tasting_notes').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw TastingNoteException(e.message);
    }
  }
}
