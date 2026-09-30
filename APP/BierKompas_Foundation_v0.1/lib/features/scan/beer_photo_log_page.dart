import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/image_utils.dart';
import '../favorites/beers.dart';
import 'beer_scan_service.dart';

const _background = Color(0xFF1E1712);
const _cardColor = Color(0xFF2C221C);
const _fieldColor = Color(0xFF241B16);
const _primary = Color(0xFFD4B28C);
const _onPrimary = Color(0xFF1E1712);
const _onSurface = Color(0xFFEFE6DD);
const _onSurfaceVariant = Color(0xFF9E8A7D);
const _outline = Color(0xFF3E312A);

/// Alternatief voor barcode scannen: zelf een foto van het bier/etiket maken
/// of uit de galerij kiezen, en aangeven welk bier het is. Er is geen
/// automatische etiketherkenning (zie beer_scan_service.dart).
class BeerPhotoLogPage extends StatefulWidget {
  const BeerPhotoLogPage({super.key});

  @override
  State<BeerPhotoLogPage> createState() => _BeerPhotoLogPageState();
}

class _BeerPhotoLogPageState extends State<BeerPhotoLogPage> {
  final _service = BeerScanService();
  final _searchController = TextEditingController();

  Uint8List? _photoBytes;
  Beer? _selectedBeer;
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Beer> get _filteredBeers {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return beers;
    return beers.where((b) => b.name.toLowerCase().contains(query) || (b.brewery ?? '').toLowerCase().contains(query)).toList();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = normalizeToJpeg(await picked.readAsBytes());
    if (!mounted) return;
    setState(() => _photoBytes = bytes);
  }

  Future<void> _choosePhotoSource() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: _primary),
              title: Text('Foto maken', style: GoogleFonts.openSans(color: _onSurface)),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: _primary),
              title: Text('Kiezen uit galerij', style: GoogleFonts.openSans(color: _onSurface)),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final photo = _photoBytes;
    final beer = _selectedBeer;
    if (photo == null || beer == null) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _error = 'Je moet ingelogd zijn om een bier te loggen.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final photoUrl = await _service.uploadPhoto(userId: user.id, bytes: photo);
      await _service.logScan(userId: user.id, beerId: beer.id, brewery: beer.brewery, photoUrl: photoUrl);
      if (!mounted) return;
      setState(() => _submitted = true);
    } on BeerScanException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _cardColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: _onSurface),
        title: Text('Foto van je bier', style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(child: _submitted ? _buildSuccess() : _buildForm()),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: _primary.withOpacity(0.12), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_outline, color: _primary, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              'Bier gelogd!',
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              '"${_selectedBeer?.name}" staat met je foto in je gescande bieren.',
              textAlign: TextAlign.center,
              style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: _onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Terug', style: GoogleFonts.openSans(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Geen barcode bij de hand? Maak een foto van het bier of etiket en kies zelf welk bier het is.',
          style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 20),
        _photoPicker(),
        const SizedBox(height: 24),
        Text('Welk bier is dit?', style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          height: 46,
          decoration: BoxDecoration(color: _fieldColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: _outline)),
          child: Row(
            children: [
              const Icon(Icons.search, color: _onSurfaceVariant, size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.openSans(color: _onSurface, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Zoek op naam of brouwerij...',
                    hintStyle: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ..._filteredBeers.take(20).map(_buildBeerOption),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text(_error!, style: GoogleFonts.openSans(color: Colors.redAccent, fontSize: 13)),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_photoBytes != null && _selectedBeer != null && !_submitting) ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: _onPrimary,
              disabledBackgroundColor: _outline,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _onPrimary))
                : Text('Loggen', style: GoogleFonts.openSans(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _photoPicker() {
    return GestureDetector(
      onTap: _choosePhotoSource,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _fieldColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _outline),
          image: _photoBytes != null ? DecorationImage(image: MemoryImage(_photoBytes!), fit: BoxFit.cover) : null,
        ),
        child: _photoBytes == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo_outlined, color: _onSurfaceVariant, size: 32),
                  const SizedBox(height: 8),
                  Text('Foto maken of kiezen', style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 13)),
                ],
              )
            : Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.edit, color: Colors.white, size: 16),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildBeerOption(Beer beer) {
    final selected = _selectedBeer?.id == beer.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedBeer = beer),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? _primary : _outline),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: beer.imageUrl != null
                      ? Image.network(
                          beer.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(color: _fieldColor, child: Icon(Icons.sports_bar_outlined, color: _primary, size: 18)),
                        )
                      : const ColoredBox(color: _fieldColor, child: Icon(Icons.sports_bar_outlined, color: _primary, size: 18)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(beer.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.openSans(color: _onSurface, fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('${beer.style} • ${beer.abv}', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 11)),
                  ],
                ),
              ),
              if (selected) const Icon(Icons.check_circle, color: _primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
