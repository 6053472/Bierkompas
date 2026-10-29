import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'beer_catalog_service.dart';

const _background = Color(0xFF1E1712);
const _cardColor = Color(0xFF2C221C);
const _primary = Color(0xFFD4B28C);
const _onSurface = Color(0xFFEFE6DD);
const _onSurfaceVariant = Color(0xFF9E8A7D);
const _outlineVariant = Color(0xFF3E312A);

/// Bierdatabase: zoeken en bladeren door alle bieren, met filter op bierstijl.
class BeerCatalogPage extends StatefulWidget {
  const BeerCatalogPage({super.key});

  @override
  State<BeerCatalogPage> createState() => _BeerCatalogPageState();
}

class _BeerCatalogPageState extends State<BeerCatalogPage> {
  final _service = BeerCatalogService();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final List<CatalogBeer> _beers = [];
  List<StyleCount> _styles = [];
  String? _selectedStyle;
  String _query = '';
  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  Timer? _debounce;
  // Verhoogt bij elke nieuwe zoekopdracht, zodat een trage vorige aanvraag
  // het nieuwe resultaat niet meer kan overschrijven.
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _service.fetchStyles().then((styles) {
      if (mounted) setState(() => _styles = styles);
    });
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _reload() async {
    final token = ++_searchToken;
    setState(() {
      _beers.clear();
      _hasMore = true;
      _error = null;
      _loading = true;
    });
    try {
      final page = await _service.search(query: _query, stijl: _selectedStyle);
      if (!mounted || token != _searchToken) return;
      setState(() {
        _beers.addAll(page);
        _hasMore = page.length == BeerCatalogService.pageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || token != _searchToken) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final token = _searchToken;
    setState(() => _loading = true);
    try {
      final page = await _service.search(query: _query, stijl: _selectedStyle, offset: _beers.length);
      if (!mounted || token != _searchToken) return;
      setState(() {
        _beers.addAll(page);
        _hasMore = page.length == BeerCatalogService.pageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || token != _searchToken) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _query = value;
      _reload();
    });
  }

  void _openDetail(CatalogBeer beer) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _BeerDetailSheet(beer: beer),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _cardColor,
        foregroundColor: _onSurface,
        iconTheme: const IconThemeData(color: _onSurface),
        elevation: 0,
        title: Text('Bierdatabase', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _outlineVariant),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: GoogleFonts.openSans(color: _onSurface, fontSize: 15),
                  cursorColor: _primary,
                  decoration: InputDecoration(
                    hintText: 'Zoek op biernaam of brouwerij...',
                    hintStyle: GoogleFonts.openSans(color: _onSurfaceVariant),
                    border: InputBorder.none,
                    icon: const Icon(Icons.search, color: _onSurfaceVariant),
                  ),
                ),
              ),
            ),
            if (_styles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _outlineVariant),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _selectedStyle,
                      isExpanded: true,
                      dropdownColor: _cardColor,
                      iconEnabledColor: _primary,
                      style: GoogleFonts.openSans(color: _onSurface, fontSize: 14),
                      hint: Text('Alle bierstijlen', style: GoogleFonts.openSans(color: _onSurfaceVariant)),
                      items: [
                        DropdownMenuItem<String?>(value: null, child: Text('Alle bierstijlen', style: GoogleFonts.openSans(color: _onSurface))),
                        for (final s in _styles)
                          DropdownMenuItem<String?>(value: s.stijl, child: Text('${s.stijl} (${s.aantal})', overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (value) {
                        _selectedStyle = value;
                        _reload();
                      },
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_beers.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }
    if (_beers.isEmpty && _error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('Kon de bierdatabase niet laden: $_error',
              textAlign: TextAlign.center, style: GoogleFonts.openSans(color: _onSurfaceVariant)),
        ),
      );
    }
    if (_beers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _query.trim().isEmpty && _selectedStyle == null
                ? 'De bierdatabase is nog leeg.'
                : 'Geen bieren gevonden.',
            textAlign: TextAlign.center,
            style: GoogleFonts.openSans(color: _onSurfaceVariant),
          ),
        ),
      );
    }
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _beers.length + (_loading || _hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index >= _beers.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(color: _primary, strokeWidth: 2)),
          );
        }
        return _BeerCard(beer: _beers[index], onTap: () => _openDetail(_beers[index]));
      },
    );
  }
}

/// Productfoto uit de bierdatabase (Belgian Beer Factory en Mitra).
Widget _beerImage(String url, BoxFit fit) => Image.network(
      url,
      fit: fit,
      // Op web laden deze afbeeldingen via een <img>-element als CORS ze blokkeert.
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      errorBuilder: (context, error, stackTrace) =>
          const Center(child: Icon(Icons.sports_bar_outlined, color: _onSurfaceVariant)),
    );

class _BeerCard extends StatelessWidget {
  final CatalogBeer beer;
  final VoidCallback onTap;

  const _BeerCard({required this.beer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tags = <String>[
      if (beer.stijl != null && beer.stijl!.isNotEmpty) beer.stijl!,
      if (beer.alcohol != null) '${beer.alcohol!.toStringAsFixed(1)}%',
      if (beer.ibu != null) '${beer.ibu} IBU',
    ];
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _outlineVariant.withOpacity(0.6)),
        ),
        child: Row(
          children: [
            if (beer.imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  color: Colors.white,
                  width: 56,
                  height: 72,
                  child: _beerImage(beer.imageUrl!, BoxFit.contain),
                ),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(beer.naam, style: GoogleFonts.playfairDisplay(color: _primary, fontSize: 17, fontWeight: FontWeight.w600)),
                  if (beer.brouwerij != null) ...[
                    const SizedBox(height: 2),
                    Text(beer.brouwerij!, style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 12)),
                  ],
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 6, children: [for (final t in tags) _tag(t)]),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _tag(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _outlineVariant),
        ),
        child: Text(label, style: GoogleFonts.openSans(color: _onSurface, fontSize: 11)),
      );
}

class _BeerDetailSheet extends StatelessWidget {
  final CatalogBeer beer;

  const _BeerDetailSheet({required this.beer});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      if (beer.stijl != null && beer.stijl!.isNotEmpty) ('Bierstijl', beer.stijl!),
      if (beer.smaakcategorie != null && beer.smaakcategorie!.isNotEmpty) ('Smaakcategorie', beer.smaakcategorie!),
      if (beer.kleur != null && beer.kleur!.isNotEmpty) ('Kleur', beer.kleur!),
      if (beer.land != null && beer.land!.isNotEmpty) ('Land', beer.land!),
      if (beer.alcohol != null) ('Alcoholpercentage', '${beer.alcohol!.toStringAsFixed(1)}%'),
      if (beer.ibu != null) ('IBU', '${beer.ibu}'),
      if (beer.gisting != null && beer.gisting!.isNotEmpty) ('Gisting', beer.gisting!),
      if (beer.verpakking != null && beer.verpakking!.isNotEmpty) ('Verpakking', beer.verpakking!),
      if (beer.smaaktonen != null && beer.smaaktonen!.isNotEmpty) ('Smaaktonen', beer.smaaktonen!),
      if (beer.untappdScore != null)
        ('Untappd', '${beer.untappdScore!.toStringAsFixed(2)}${beer.untappdAantal != null ? ' (${beer.untappdAantal} beoordelingen)' : ''}'),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _outlineVariant, borderRadius: BorderRadius.circular(20))),
            ),
            const SizedBox(height: 18),
            if (beer.imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.white,
                  width: double.infinity,
                  height: 220,
                  child: _beerImage(beer.imageUrl!, BoxFit.contain),
                ),
              ),
              const SizedBox(height: 18),
            ],
            Text(beer.naam, style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 24, fontWeight: FontWeight.w700)),
            if (beer.brouwerij != null) ...[
              const SizedBox(height: 4),
              Text(beer.brouwerij!, style: GoogleFonts.openSans(color: _primary, fontSize: 14)),
            ],
            const SizedBox(height: 16),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 130, child: Text(label, style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 13))),
                    Expanded(child: Text(value, style: GoogleFonts.openSans(color: _onSurface, fontSize: 13, height: 1.4))),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Text('Bron: ${beer.bron}', style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 11)),
            if (beer.bronUrl != null)
              TextButton.icon(
                onPressed: () => launchUrl(Uri.parse(beer.bronUrl!), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new, color: _primary, size: 16),
                label: Text('Bekijk bij de bron', style: GoogleFonts.openSans(color: _primary, fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }
}
