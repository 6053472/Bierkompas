import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'beer_photo_log_page.dart';
import 'beer_scan_page.dart';
import 'beer_scan_service.dart';

const _background = Color(0xFF1E1712);
const _cardColor = Color(0xFF2C221C);
const _primary = Color(0xFFD4B28C);
const _onPrimary = Color(0xFF1E1712);
const _onSurface = Color(0xFFEFE6DD);
const _onSurfaceVariant = Color(0xFF9E8A7D);
const _outline = Color(0xFF3E312A);

/// "Bier scannen": een scan-knop bovenaan en daaronder alle bieren die je
/// gescand hebt, zodat je ze terug kunt vinden.
class ScannedBeersPage extends StatefulWidget {
  const ScannedBeersPage({super.key});

  @override
  State<ScannedBeersPage> createState() => _ScannedBeersPageState();
}

class _ScannedBeersPageState extends State<ScannedBeersPage> {
  final _service = BeerScanService();
  List<ScannedBeer> _scanned = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final scanned = await _service.listScannedBeers();
      if (!mounted) return;
      setState(() {
        _scanned = scanned;
        _loading = false;
      });
    } on BeerScanException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _openScanner() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BeerScanPage()));
    if (mounted) _load();
  }

  Future<void> _openPhotoLog() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BeerPhotoLogPage()));
    if (mounted) _load();
  }

  String _formatDate(DateTime date) {
    const months = ['jan', 'feb', 'mrt', 'apr', 'mei', 'jun', 'jul', 'aug', 'sep', 'okt', 'nov', 'dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _cardColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: _onSurface),
        title: Text('Bier scannen', style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: _primary,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              Text(
                'Scan de barcode van een biertje, of maak zelf een foto als je geen barcode bij de hand hebt. Alles wat je logt vind je hieronder terug.',
                style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openScanner,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text('Scan een bier', style: GoogleFonts.openSans(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: _onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openPhotoLog,
                  icon: const Icon(Icons.add_a_photo_outlined, color: _primary),
                  label: Text('Foto van je bier', style: GoogleFonts.openSans(color: _primary, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _primary),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Text('Mijn gescande bieren', style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 10),
                  if (!_loading && _error == null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(999)),
                      child: Text('${_scanned.length}', style: GoogleFonts.openSans(color: _onPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _primary)),
                )
              else if (_error != null)
                _message(_error!, retry: true)
              else if (_scanned.isEmpty)
                _message('Je hebt nog geen bieren gescand. Tik op "Scan een bier" om te beginnen.')
              else
                for (final item in _scanned) ...[
                  _buildBeerTile(item),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _message(String text, {bool retry = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: _outline)),
      child: Column(
        children: [
          Text(text, textAlign: TextAlign.center, style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 13, height: 1.5)),
          if (retry) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: Text('Opnieuw proberen', style: GoogleFonts.openSans(color: _primary, fontWeight: FontWeight.bold))),
          ],
        ],
      ),
    );
  }

  Widget _buildBeerTile(ScannedBeer item) {
    final beer = item.beer;
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        iconColor: _primary,
        collapsedIconColor: _onSurfaceVariant,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 48,
            height: 48,
            child: (item.photoUrl ?? beer.imageUrl) != null
                ? Image.network(
                    (item.photoUrl ?? beer.imageUrl)!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(color: _background, child: Icon(Icons.sports_bar_outlined, color: _primary)),
                  )
                : const ColoredBox(color: _background, child: Icon(Icons.sports_bar_outlined, color: _primary)),
          ),
        ),
        title: Text(beer.name, style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 17, fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${beer.style} • ${beer.abv}\nGescand op ${_formatDate(item.scannedAt)}',
          style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 12, height: 1.4),
        ),
        children: [
          _infoBlock('Wat is het', beer.description),
          _infoBlock('Hoe het gemaakt wordt', beer.howMade),
          _infoBlock('Soort bier', beer.styleInfo),
          if (beer.brewery != null)
            Row(
              children: [
                const Icon(Icons.factory_outlined, color: _primary, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(beer.brewery!, style: GoogleFonts.openSans(color: _onSurface, fontSize: 13))),
              ],
            ),
        ],
      ),
    );
  }

  Widget _infoBlock(String label, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: GoogleFonts.openSans(color: _primary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.6)),
          const SizedBox(height: 4),
          Text(text, style: GoogleFonts.openSans(color: _onSurface, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}
