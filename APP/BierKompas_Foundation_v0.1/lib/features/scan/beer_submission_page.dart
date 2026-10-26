import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/image_utils.dart';
import '../favorites/beers.dart';
import 'beer_scan_service.dart';
import 'beer_submission_service.dart';

// Zelfde kleurenpalet als de scanner en "Brouwerij toevoegen".
const _background = Color(0xFF1E1712);
const _cardColor = Color(0xFF2C221C);
const _fieldColor = Color(0xFF241B16);
const _primary = Color(0xFFD4B28C);
const _onPrimary = Color(0xFF1E1712);
const _onSurface = Color(0xFFEFE6DD);
const _onSurfaceVariant = Color(0xFF9E8A7D);
const _outlineVariant = Color(0xFF3E312A);

/// Formulier om een onbekend bier aan te melden, bijv. als de scanner geen
/// match vindt. Een beheerder keurt het goed voordat het voor iedereen in
/// Bierkompas staat (zie supabase/add_bier_aanmelden.sql).
///
/// Kiest de gebruiker toch een bier dat al bestaat (uit de lijst "Bedoel je
/// een van deze?"), dan sluit de pagina met dat [Beer] als resultaat.
class BeerSubmissionPage extends StatefulWidget {
  const BeerSubmissionPage({super.key, this.barcode, this.initialName});

  /// Gescande barcode zonder match (optioneel).
  final String? barcode;

  /// Vooringevulde naam, bijv. de zoekterm uit "Foto van je bier".
  final String? initialName;

  @override
  State<BeerSubmissionPage> createState() => _BeerSubmissionPageState();
}

class _BeerSubmissionPageState extends State<BeerSubmissionPage> {
  final _formKey = GlobalKey<FormState>();
  final _service = BeerSubmissionService();

  late final _naamController = TextEditingController(text: widget.initialName ?? '');
  final _brouwerijController = TextEditingController();
  final _stijlController = TextEditingController();
  final _abvController = TextEditingController();
  final _beschrijvingController = TextEditingController();

  Uint8List? _photoBytes;
  List<Beer> _similar = const [];
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _similar = _service.findSimilar(_naamController.text);
  }

  @override
  void dispose() {
    _naamController.dispose();
    _brouwerijController.dispose();
    _stijlController.dispose();
    _abvController.dispose();
    _beschrijvingController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = normalizeToJpeg(await picked.readAsBytes());
    if (!mounted) return;
    setState(() => _photoBytes = bytes);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      String? photoUrl;
      if (_photoBytes != null) {
        photoUrl = await BeerScanService().uploadPhoto(userId: user.id, bytes: _photoBytes!);
      }
      await _service.submit(
        userId: user.id,
        naam: _naamController.text,
        brouwerij: _brouwerijController.text,
        stijl: _stijlController.text,
        abv: _abvController.text,
        beschrijving: _beschrijvingController.text,
        barcode: widget.barcode,
        photoUrl: photoUrl,
      );
      if (!mounted) return;
      setState(() => _submitted = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is BeerSubmissionException ? e.message : 'Aanmelden mislukt. Probeer het opnieuw.');
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
        title: Text(
          'Bier aanmelden',
          style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 20, fontWeight: FontWeight.bold),
        ),
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
              child: const Icon(Icons.hourglass_top_outlined, color: _primary, size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              'Bier aangemeld',
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              'Bedankt! Een beheerder bekijkt je aanmelding. Zodra het bier is goedgekeurd, staat het in Bierkompas en krijg je een bericht.',
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
                child: Text('Klaar', style: GoogleFonts.openSans(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Staat je bier nog niet in Bierkompas? Meld het aan. Na goedkeuring door een beheerder kan iedereen het vinden en loggen.',
            style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 13, height: 1.5),
          ),
          if (widget.barcode != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.qr_code, color: _onSurfaceVariant, size: 16),
                const SizedBox(width: 6),
                Text('Barcode: ${widget.barcode}', style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ],
          const SizedBox(height: 20),
          _photoPicker(),
          const SizedBox(height: 20),
          _field(
            controller: _naamController,
            label: 'Naam van het bier',
            hint: 'Bijv. Gouden Hop Tripel',
            required: true,
            onChanged: (value) => setState(() => _similar = _service.findSimilar(value)),
          ),
          if (_similar.isNotEmpty) _buildSimilar(),
          const SizedBox(height: 14),
          _field(controller: _brouwerijController, label: 'Brouwerij', hint: 'Bijv. Brouwerij De Gouden Hop', required: true),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _field(controller: _stijlController, label: 'Stijl (optioneel)', hint: 'Bijv. Tripel')),
              const SizedBox(width: 12),
              Expanded(child: _field(controller: _abvController, label: 'Alcohol (optioneel)', hint: 'Bijv. 8,0%')),
            ],
          ),
          const SizedBox(height: 14),
          _field(controller: _beschrijvingController, label: 'Beschrijving (optioneel)', hint: 'Smaak, kleur, waar gedronken...', maxLines: 3),
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
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: _onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: _onPrimary))
                  : Text('Aanmelden ter goedkeuring', style: GoogleFonts.openSans(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  /// "Bedoel je een van deze?" -- bestaande bieren die op de naam lijken.
  Widget _buildSimilar() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primary.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bedoel je een van deze? Ze staan al in Bierkompas.',
              style: GoogleFonts.openSans(color: _primary, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          for (final beer in _similar)
            InkWell(
              onTap: () => Navigator.of(context).pop(beer),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.sports_bar, color: _onSurfaceVariant, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${beer.name}${beer.brewery != null ? ' · ${beer.brewery}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.openSans(color: _onSurface, fontSize: 13),
                      ),
                    ),
                    Text('Kiezen', style: GoogleFonts.openSans(color: _primary, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _photoPicker() {
    return GestureDetector(
      onTap: _pickPhoto,
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _fieldColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _outlineVariant),
          image: _photoBytes != null ? DecorationImage(image: MemoryImage(_photoBytes!), fit: BoxFit.cover) : null,
        ),
        child: _photoBytes == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo_outlined, color: _onSurfaceVariant, size: 32),
                  const SizedBox(height: 8),
                  Text('Foto van het etiket (optioneel)', style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 13)),
                ],
              )
            : null,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool required = false,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          validator: required ? (value) => (value == null || value.trim().isEmpty) ? 'Verplicht veld' : null : null,
          style: GoogleFonts.openSans(color: _onSurface, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.openSans(color: _onSurfaceVariant.withOpacity(0.6), fontSize: 14),
            filled: true,
            fillColor: _fieldColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _outlineVariant)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primary)),
          ),
        ),
      ],
    );
  }
}
