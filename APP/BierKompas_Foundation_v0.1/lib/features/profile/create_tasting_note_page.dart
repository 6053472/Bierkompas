import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../favorites/beers.dart';
import 'stats_service.dart';
import 'tasting_notes_service.dart';

const _background = Color(0xFF1E1712);
const _cardColor = Color(0xFF2C221C);
const _primary = Color(0xFFD4B28C);
const _onPrimary = Color(0xFF1E1712);
const _onSurface = Color(0xFFEFE6DD);
const _onSurfaceVariant = Color(0xFF9E8A7D);
const _outlineVariant = Color(0xFF3E312A);

/// Scherm om een nieuwe proefnotitie toe te voegen bij een bier.
class CreateTastingNotePage extends StatefulWidget {
  const CreateTastingNotePage({super.key});

  @override
  State<CreateTastingNotePage> createState() => _CreateTastingNotePageState();
}

class _CreateTastingNotePageState extends State<CreateTastingNotePage> {
  final _service = TastingNotesService();
  final _beerNameController = TextEditingController();
  final _noteController = TextEditingController();

  Beer? _selectedBeer;
  int _rating = 5;
  bool _saving = false;

  @override
  void dispose() {
    _beerNameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final beerName = _beerNameController.text.trim();
    final note = _noteController.text.trim();
    if (beerName.isEmpty || note.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final created = await _service.create(
        beerName: beerName,
        note: note,
        rating: _rating,
        beerId: _selectedBeer?.name == beerName ? _selectedBeer?.id : null,
      );
      await _recordStreakActivity();
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } on TastingNoteException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Opslaan mislukt: $e')),
      );
    }
  }

  // Een proefnotitie is een "bier beoordelen"-actie voor de Bier Streak.
  // Mislukt dit (bijv. geen netwerk), dan mag dat de opgeslagen notitie niet blokkeren.
  Future<void> _recordStreakActivity() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await StatsService().recordDailyActivity(user.id);
    } catch (_) {
      // Stilzwijgend negeren: de streak is secundair aan het opslaan van de notitie.
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _beerNameController.text.trim().isNotEmpty &&
        _noteController.text.trim().isNotEmpty &&
        !_saving;
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _cardColor,
        foregroundColor: _onSurface,
        iconTheme: const IconThemeData(color: _onSurface),
        elevation: 0,
        title: Text('Nieuwe proefnotitie', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: TextButton(
                onPressed: canSave ? _submit : null,
                style: TextButton.styleFrom(
                  backgroundColor: canSave ? _primary : _outlineVariant,
                  foregroundColor: canSave ? _onPrimary : _onSurfaceVariant,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _onPrimary),
                      )
                    : Text('Opslaan', style: GoogleFonts.openSans(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Bier',
              style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Autocomplete<Beer>(
              textEditingController: _beerNameController,
              optionsBuilder: (value) {
                if (value.text.trim().isEmpty) return const Iterable<Beer>.empty();
                final query = value.text.toLowerCase();
                return beers.where((b) => b.name.toLowerCase().contains(query));
              },
              displayStringForOption: (b) => b.name,
              onSelected: (b) => setState(() => _selectedBeer = b),
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: (text) => setState(() {
                    if (text.trim() != _selectedBeer?.name) _selectedBeer = null;
                  }),
                  style: GoogleFonts.openSans(color: _onSurface, fontSize: 15),
                  cursorColor: _primary,
                  decoration: _inputDecoration('Naam van het bier'),
                );
              },
              optionsViewBuilder: (context, onSelected, options) => Align(
                alignment: Alignment.topLeft,
                child: Material(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220, maxWidth: 400),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        return ListTile(
                          title: Text(option.name, style: GoogleFonts.openSans(color: _onSurface)),
                          subtitle: option.brewery != null
                              ? Text(option.brewery!, style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 12))
                              : null,
                          onTap: () => onSelected(option),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Beoordeling',
              style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                return IconButton(
                  onPressed: () => setState(() => _rating = starIndex),
                  icon: Icon(
                    starIndex <= _rating ? Icons.star : Icons.star_border,
                    color: _primary,
                    size: 28,
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            Text(
              'Proefnotitie',
              style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _outlineVariant.withOpacity(0.6)),
              ),
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: _noteController,
                maxLines: 6,
                minLines: 4,
                maxLength: 500,
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.openSans(color: _onSurface, fontSize: 15),
                cursorColor: _primary,
                decoration: InputDecoration(
                  hintText: 'Hoe smaakte het? Kleur, geur, afdronk...',
                  hintStyle: GoogleFonts.openSans(color: _onSurfaceVariant),
                  border: InputBorder.none,
                  counterStyle: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.openSans(color: _onSurfaceVariant),
        filled: true,
        fillColor: _cardColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _outlineVariant.withOpacity(0.6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _outlineVariant.withOpacity(0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary),
        ),
      );
}
