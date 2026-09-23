import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'create_tasting_note_page.dart';
import 'tasting_notes_service.dart';

const _background = Color(0xFF1E1712);
const _cardColor = Color(0xFF2C221C);
const _primary = Color(0xFFD4B28C);
const _onPrimary = Color(0xFF1E1712);
const _onSurface = Color(0xFFEFE6DD);
const _onSurfaceVariant = Color(0xFF9E8A7D);

/// Volledig overzicht van alle proefnotities, geopend via "Bekijk alle" op het
/// profiel. Laat ook toe om een nieuwe notitie toe te voegen of te verwijderen.
class AllTastingNotesPage extends StatefulWidget {
  const AllTastingNotesPage({super.key, required this.notes});

  final List<TastingNote> notes;

  @override
  State<AllTastingNotesPage> createState() => _AllTastingNotesPageState();
}

class _AllTastingNotesPageState extends State<AllTastingNotesPage> {
  final _service = TastingNotesService();
  late List<TastingNote> _notes;

  /// Of de lijst is gewijzigd (toegevoegd/verwijderd), zodat het profiel bij
  /// het terugkeren zijn eigen kopie kan verversen.
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _notes = List.of(widget.notes);
  }

  Future<void> _addNote() async {
    final created = await Navigator.of(context).push<TastingNote>(
      MaterialPageRoute(builder: (_) => const CreateTastingNotePage()),
    );
    if (created == null) return;
    setState(() {
      _notes.insert(0, created);
      _changed = true;
    });
  }

  Future<void> _deleteNote(TastingNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text('Notitie verwijderen?', style: GoogleFonts.playfairDisplay(color: _onSurface)),
        content: Text(
          'Weet je zeker dat je je proefnotitie over "${note.beerName}" wilt verwijderen?',
          style: GoogleFonts.openSans(color: _onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Annuleren', style: GoogleFonts.openSans(color: _onSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Verwijderen', style: GoogleFonts.openSans(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.delete(note.id);
      setState(() {
        _notes.removeWhere((n) => n.id == note.id);
        _changed = true;
      });
    } on TastingNoteException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verwijderen mislukt: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_changed ? _notes : null);
      },
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _cardColor,
          foregroundColor: _onSurface,
          elevation: 0,
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: _primary,
          foregroundColor: _onPrimary,
          onPressed: _addNote,
          child: const Icon(Icons.add),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(
                'Mijn Proefnotities',
                style: GoogleFonts.playfairDisplay(
                  color: _onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Alles wat je hebt geproefd en opgeschreven, op één plek.',
                style: GoogleFonts.inter(color: _onSurfaceVariant, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              if (_notes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      const Icon(Icons.local_bar_outlined, color: _onSurfaceVariant, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        'Je hebt nog geen proefnotities.\nTik op + om je eerste bier te noteren.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: _onSurfaceVariant, fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                )
              else
                for (final note in _notes) ...[
                  _NoteCard(note: note, onDelete: () => _deleteNote(note)),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onDelete});

  final TastingNote note;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF3C3028),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.sports_bar, color: _onSurfaceVariant, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        note.beerName,
                        style: GoogleFonts.playfairDisplay(
                          color: _onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Row(
                      children: List.generate(
                        5,
                        (index) => Icon(
                          index < note.rating ? Icons.star : Icons.star_border,
                          color: _primary,
                          size: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  note.note,
                  style: GoogleFonts.inter(color: _onSurfaceVariant, fontSize: 12, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatDate(note.createdAt),
                  style: GoogleFonts.inter(color: _onSurfaceVariant, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: _onSurfaceVariant, size: 20),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    const months = [
      'jan', 'feb', 'mrt', 'apr', 'mei', 'jun',
      'jul', 'aug', 'sep', 'okt', 'nov', 'dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
