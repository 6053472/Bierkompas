import 'package:supabase_flutter/supabase_flutter.dart';

/// De vaste rubrieken van de Support/FAQ, in weergavevolgorde.
/// De sleutels komen overeen met `faq_items.category` (zie supabase/add_faq.sql).
const faqCategories = <(String key, String label)>[
  ('account', 'Account- en profielinstellingen'),
  ('inchecken', 'Inchecken'),
  ('bieren', 'Bieren en beoordelingen'),
  ('badges', 'Badges'),
  ('vrienden', 'Vrienden en interactie'),
  ('bronnen', 'Toevoegen van bronnen en content'),
];

class FaqItem {
  final int id;
  final String category;
  final String question;
  final String answer;

  const FaqItem({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
  });

  factory FaqItem.fromJson(Map<String, dynamic> json) => FaqItem(
        id: json['id'] as int,
        category: json['category'] as String,
        question: json['question'] as String,
        answer: json['answer'] as String,
      );
}

class FaqException implements Exception {
  final String message;
  FaqException(this.message);

  @override
  String toString() => message;
}

/// Leest de veelgestelde vragen uit de Supabase-tabel `faq_items`.
class FaqService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<List<FaqItem>> fetchAll() async {
    try {
      final rows = await _client.from('faq_items').select().order('sort_order').order('id');
      return (rows as List).map((e) => FaqItem.fromJson(e as Map<String, dynamic>)).toList();
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205' || e.code == '42P01') return [];
      throw FaqException(e.message);
    }
  }
}
