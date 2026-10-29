import 'package:supabase_flutter/supabase_flutter.dart';

class CatalogBeer {
  final int id;
  final String naam;
  final String? brouwerij;
  final String? stijl;
  final String? smaakcategorie;
  final String? verpakking;
  final String? land;
  final double? alcohol;
  final int? ibu;
  final String? gisting;
  final String? smaaktonen;
  final double? untappdScore;
  final int? untappdAantal;
  final String bron;
  final String? bronUrl;
  final String? imageUrl;
  final String? kleur;

  const CatalogBeer({
    required this.id,
    required this.naam,
    required this.bron,
    this.brouwerij,
    this.stijl,
    this.smaakcategorie,
    this.verpakking,
    this.land,
    this.alcohol,
    this.ibu,
    this.gisting,
    this.smaaktonen,
    this.untappdScore,
    this.untappdAantal,
    this.bronUrl,
    this.imageUrl,
    this.kleur,
  });

  factory CatalogBeer.fromJson(Map<String, dynamic> json) => CatalogBeer(
        id: json['id'] as int,
        naam: json['naam'] as String,
        brouwerij: json['brouwerij'] as String?,
        stijl: json['stijl'] as String?,
        smaakcategorie: json['smaakcategorie'] as String?,
        verpakking: json['verpakking'] as String?,
        land: json['land'] as String?,
        alcohol: (json['alcohol'] as num?)?.toDouble(),
        ibu: (json['ibu'] as num?)?.toInt(),
        gisting: json['gisting'] as String?,
        smaaktonen: json['smaaktonen'] as String?,
        untappdScore: (json['untappd_score'] as num?)?.toDouble(),
        untappdAantal: (json['untappd_aantal'] as num?)?.toInt(),
        bron: json['bron'] as String? ?? 'Stichting Erfgoed Nederlandse Biercultuur',
        bronUrl: json['bron_url'] as String?,
        imageUrl: json['image_url'] as String?,
        kleur: json['kleur'] as String?,
      );
}

class StyleCount {
  final String stijl;
  final int aantal;
  const StyleCount(this.stijl, this.aantal);
}

class BeerCatalogException implements Exception {
  final String message;
  BeerCatalogException(this.message);

  @override
  String toString() => message;
}

/// Zoekt in de bierdatabase (tabel `beer_catalog`, zie
/// supabase/add_external_content_imports.sql). Zoeken en bladeren gebeurt op
/// de server, in pagina's: de database bevat ruim 4.000 bieren.
class BeerCatalogService {
  static const pageSize = 30;

  SupabaseClient get _client => Supabase.instance.client;

  /// Zoekt bieren. Met een zoekterm komen de resultaten in drie lagen, elk
  /// alfabetisch: eerst bieren waarvan de naam met de term begint (dus ook de
  /// exacte match), dan bieren waarvan de naam de term ergens bevat, en als
  /// laatste bieren waarbij alleen de brouwerij of stijl overeenkomt. Zo staat
  /// "Dubbel Trubbel" bij "dubbel" bovenaan i.p.v. tussen alle andere dubbels.
  Future<List<CatalogBeer>> search({String query = '', String? stijl, int offset = 0}) async {
    try {
      // Tekens met een betekenis in de filtertaal van PostgREST weghalen, zodat
      // een zoekterm met een komma of haakje de aanvraag niet breekt.
      final term = query.trim().replaceAll(RegExp(r'[,()%*\\]'), ' ').trim();
      if (term.isEmpty) {
        final rows = await _withStyle(_client.from('beer_catalog').select(), stijl)
            .order('naam')
            .range(offset, offset + pageSize - 1);
        return _toBeers(rows);
      }

      // De drie lagen achter elkaar gezet; per laag het stuk ophalen dat in
      // het venster [offset, offset + pageSize) valt.
      final tiers = <PostgrestFilterBuilder<List<Map<String, dynamic>>> Function()>[
        () => _withStyle(_client.from('beer_catalog').select(), stijl).ilike('naam', '$term%'),
        () => _withStyle(_client.from('beer_catalog').select(), stijl)
            .ilike('naam', '%$term%')
            .not('naam', 'ilike', '$term%'),
        () => _withStyle(_client.from('beer_catalog').select(), stijl)
            .not('naam', 'ilike', '%$term%')
            .or('brouwerij.ilike.%$term%,stijl.ilike.%$term%'),
      ];

      final result = <CatalogBeer>[];
      var skip = offset;
      for (final tier in tiers) {
        final needed = pageSize - result.length;
        if (needed <= 0) break;
        final total = (await tier().limit(1).count(CountOption.exact)).count;
        if (skip >= total) {
          skip -= total;
          continue;
        }
        final rows = await tier().order('naam').range(skip, skip + needed - 1);
        result.addAll(_toBeers(rows));
        skip = 0;
      }
      return result;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST205' || e.code == '42P01') return [];
      throw BeerCatalogException(e.message);
    }
  }

  PostgrestFilterBuilder<List<Map<String, dynamic>>> _withStyle(
    PostgrestFilterBuilder<List<Map<String, dynamic>>> request,
    String? stijl,
  ) =>
      stijl != null && stijl.isNotEmpty ? request.eq('stijl', stijl) : request;

  List<CatalogBeer> _toBeers(List<dynamic> rows) =>
      rows.map((e) => CatalogBeer.fromJson(e as Map<String, dynamic>)).toList();

  Future<List<StyleCount>> fetchStyles() async {
    try {
      final rows = await _client.rpc('beer_catalog_styles');
      return (rows as List)
          .map((e) => StyleCount(e['stijl'] as String, (e['aantal'] as num).toInt()))
          .toList();
    } on PostgrestException {
      return [];
    }
  }
}
