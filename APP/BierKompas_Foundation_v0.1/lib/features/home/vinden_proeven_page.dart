import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../books/books_page.dart';
import '../music/music_page.dart';
import '../scan/scanned_beers_page.dart';

const _background = Color(0xFF1E1712);
const _cardColor = Color(0xFF2C221C);
const _primary = Color(0xFFD4B28C);
const _onSurface = Color(0xFFEFE6DD);
const _onSurfaceVariant = Color(0xFF9E8A7D);
const _outline = Color(0xFF3E312A);

/// Overzicht achter de "Vinden & Proeven"-tegel op Ontdek: Bier scannen,
/// Boeken en Muziek.
class VindenProevenPage extends StatelessWidget {
  const VindenProevenPage({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _cardColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: _onSurface),
        title: Text('Vinden & Proeven', style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Text(
              'Ontdek bieren, lees erover en luister ernaar.',
              style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),
            _OptionCard(
              icon: Icons.qr_code_scanner,
              title: 'Bier scannen',
              subtitle: 'Scan een biertje en vind je gescande bieren terug',
              onTap: () => _open(context, const ScannedBeersPage()),
            ),
            const SizedBox(height: 16),
            _OptionCard(
              icon: Icons.menu_book_outlined,
              title: 'Boeken',
              subtitle: 'Je leeslijst met bierboeken',
              onTap: () => _open(context, const BooksPage()),
            ),
            const SizedBox(height: 16),
            _OptionCard(
              icon: Icons.music_note_outlined,
              title: 'Muziek',
              subtitle: 'Brouwers Beats: de ultieme bier-taplijst',
              onTap: () => _open(context, const MusicPage()),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _outline),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: _primary.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, color: _primary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 20, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 13, height: 1.4)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
