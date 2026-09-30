import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'music.dart';

const _background = Color(0xFF1E1712);
const _cardColor = Color(0xFF2C221C);
const _primary = Color(0xFFD4B28C);
const _onPrimary = Color(0xFF1E1712);
const _onSurface = Color(0xFFEFE6DD);
const _onSurfaceVariant = Color(0xFF9E8A7D);
const _outline = Color(0xFF3E312A);

/// "Brouwers Beats": biernummers om te ontdekken (design:
/// bierkompas paginas/biermuziek/brouwers_beats_de_ultieme_taplijst_nl).
/// Geen Spotify-koppeling -- elk nummer linkt naar een zoekopdracht om het
/// elders te beluisteren, zodat er geen Premium-account nodig is.
class MusicPage extends StatefulWidget {
  const MusicPage({super.key});

  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Song> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return songs;
    return songs.where((s) => s.title.toLowerCase().contains(query) || s.artist.toLowerCase().contains(query)).toList();
  }

  Future<void> _play(Song song) async {
    final opened = await launchUrl(Uri.parse(song.listenUrl), mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kon "${song.title}" niet openen.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final featured = songs.firstWhere((s) => s.featured, orElse: () => songs.first);
    final rest = filtered.where((s) => s.id != featured.id).toList();

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _cardColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: _onSurface),
        title: Text('Brouwers Beats', style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              height: 48,
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _outline),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: _onSurfaceVariant, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      style: GoogleFonts.openSans(color: _onSurface, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Zoek naar nummers, artiesten...',
                        hintStyle: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_searchController.text.trim().isEmpty) ...[
              const SizedBox(height: 28),
              Text('Muziek van de Dag', style: GoogleFonts.playfairDisplay(color: _primary, fontSize: 22, fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              _buildFeatured(featured),
            ],
            const SizedBox(height: 28),
            Row(
              children: [
                const Icon(Icons.sports_bar, color: _primary, size: 20),
                const SizedBox(width: 8),
                Text('Café-Klassiekers (NL/BE)', style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 18, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            if (rest.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('Geen nummers gevonden.', textAlign: TextAlign.center, style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 14)),
              )
            else
              for (final song in rest) ...[
                _buildSongTile(song),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeatured(Song song) {
    return GestureDetector(
      onTap: () => _play(song),
      child: Container(
        height: 320,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(song.coverAsset, fit: BoxFit.cover, cacheHeight: 900),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, _background.withOpacity(0.95)],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('FEATURED', style: GoogleFonts.openSans(color: _primary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
                        const SizedBox(height: 4),
                        Text(song.title, style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 24, fontWeight: FontWeight.bold)),
                        Text(song.artist, style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 14)),
                      ],
                    ),
                  ),
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(color: _primary, shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow, color: _onPrimary, size: 30),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongTile(Song song) {
    return InkWell(
      onTap: () => _play(song),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _outline),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(song.coverAsset, width: 56, height: 56, fit: BoxFit.cover, cacheWidth: 200),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.playfairDisplay(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: _primary.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.play_arrow, color: _primary, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
