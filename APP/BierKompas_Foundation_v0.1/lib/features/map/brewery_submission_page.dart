import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/image_utils.dart';
import 'brewery_submission_service.dart';

const _background = Color(0xFF1E1712);
const _cardColor = Color(0xFF2C221C);
const _fieldColor = Color(0xFF241B16);
const _primary = Color(0xFFD4B28C);
const _onPrimary = Color(0xFF1E1712);
const _onSurface = Color(0xFFEFE6DD);
const _onSurfaceVariant = Color(0xFF9E8A7D);
const _outlineVariant = Color(0xFF3E312A);

/// Formulier om een eigen brouwerij aan te melden voor de kaart. De
/// aanmelding is pas zichtbaar voor andere gebruikers nadat een beheerder
/// 'm heeft goedgekeurd (zie supabase/add_brewery_submissions.sql).
class BrewerySubmissionPage extends StatefulWidget {
  const BrewerySubmissionPage({super.key});

  @override
  State<BrewerySubmissionPage> createState() => _BrewerySubmissionPageState();
}

class _BrewerySubmissionPageState extends State<BrewerySubmissionPage> {
  final _formKey = GlobalKey<FormState>();
  final _service = BrewerySubmissionService();

  final _naamController = TextEditingController();
  final _beschrijvingController = TextEditingController();
  final _straatController = TextEditingController();
  final _huisnummerController = TextEditingController();
  final _postcodeController = TextEditingController();
  final _stadController = TextEditingController();

  Uint8List? _photoBytes;
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _naamController.dispose();
    _beschrijvingController.dispose();
    _straatController.dispose();
    _huisnummerController.dispose();
    _postcodeController.dispose();
    _stadController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
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
        photoUrl = await _service.uploadPhoto(userId: user.id, bytes: _photoBytes!);
      }

      await _service.submit(
        userId: user.id,
        naam: _naamController.text.trim(),
        beschrijving: _beschrijvingController.text.trim(),
        street: _straatController.text.trim(),
        houseNumber: _huisnummerController.text.trim(),
        postalCode: _postcodeController.text.trim(),
        city: _stadController.text.trim(),
        photoUrl: photoUrl,
      );

      if (!mounted) return;
      setState(() => _submitted = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is BrewerySubmissionException ? e.message : 'Aanmelden mislukt. Probeer het opnieuw.');
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
          'Brouwerij toevoegen',
          style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: _submitted ? _buildSuccess() : _buildForm(),
      ),
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
              'Aanmelding verstuurd',
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              'Bedankt! Je brouwerij wordt eerst beoordeeld door een beheerder. Zodra die is goedgekeurd, verschijnt hij op de kaart voor alle gebruikers.',
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
                child: Text('Terug naar de kaart', style: GoogleFonts.openSans(fontWeight: FontWeight.bold)),
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
            'Vul de gegevens van je brouwerij in. Na goedkeuring door een beheerder wordt hij zichtbaar op de kaart voor alle Bierkompas-gebruikers.',
            style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),
          _photoPicker(),
          const SizedBox(height: 20),
          _field(controller: _naamController, label: 'Naam brouwerij', hint: 'Bijv. Brouwerij De Gouden Hop'),
          const SizedBox(height: 14),
          _field(controller: _beschrijvingController, label: 'Beschrijving', hint: 'Vertel iets over je brouwerij...', maxLines: 4),
          const SizedBox(height: 14),
          _field(controller: _straatController, label: 'Straat', hint: 'Bijv. Dorpsstraat'),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _field(controller: _huisnummerController, label: 'Huisnummer', hint: '12')),
              const SizedBox(width: 12),
              Expanded(child: _field(controller: _postcodeController, label: 'Postcode', hint: '1234 AB')),
            ],
          ),
          const SizedBox(height: 14),
          _field(controller: _stadController, label: 'Plaats', hint: 'Bijv. Utrecht'),
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
                  const Icon(Icons.add_photo_alternate_outlined, color: _onSurfaceVariant, size: 32),
                  const SizedBox(height: 8),
                  Text('Foto van de locatie toevoegen', style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 13)),
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: (value) => (value == null || value.trim().isEmpty) ? 'Verplicht veld' : null,
          style: GoogleFonts.openSans(color: _onSurface, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.openSans(color: _onSurfaceVariant.withOpacity(0.6), fontSize: 14),
            filled: true,
            fillColor: _fieldColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _outlineVariant)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primary)),
          ),
        ),
      ],
    );
  }
}
