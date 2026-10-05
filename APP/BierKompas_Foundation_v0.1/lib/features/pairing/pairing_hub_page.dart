import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'pairing_service.dart';

const _background = Color(0xFF1E1712);
const _cardColor = Color(0xFF2C221C);
const _primary = Color(0xFFD4B28C);
const _onSurface = Color(0xFFEFE6DD);
const _onSurfaceVariant = Color(0xFF9E8A7D);
const _outlineVariant = Color(0xFF3E312A);

enum _SearchMode { gerecht, bier }

/// Foodpairing Hub: "Wat eet je?" zoekt bieren bij een gerecht, "Wat drink
/// je?" zoekt gerechten bij een bier. Data komt van Huub (zie
/// supabase/add_beer_pairings.sql).
class PairingHubPage extends StatefulWidget {
  const PairingHubPage({super.key});

  @override
  State<PairingHubPage> createState() => _PairingHubPageState();
}

class _PairingHubPageState extends State<PairingHubPage> {
  final _service = PairingService();
  late Future<List<BeerPairing>> _future;
  _SearchMode? _mode;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _service.fetchAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openMode(_SearchMode mode) {
    setState(() {
      _mode = mode;
      _query = '';
      _searchController.clear();
    });
  }

  List<BeerPairing> _filtered(List<BeerPairing> all) {
    if (_mode == null || _query.trim().isEmpty) return const [];
    final q = _query.trim().toLowerCase();
    if (_mode == _SearchMode.gerecht) {
      return all.where((p) => p.aanbevolenGerecht.toLowerCase().contains(q)).toList();
    }
    return all.where((p) => p.biernaam.toLowerCase().contains(q) || p.brouwerij.toLowerCase().contains(q)).toList();
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
        title: Text('Foodpairing Hub', style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: FutureBuilder<List<BeerPairing>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: _primary));
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('Kon pairings niet laden: ${snapshot.error}',
                    style: GoogleFonts.openSans(color: _onSurfaceVariant)),
              );
            }
            final all = snapshot.data ?? const [];
            final results = _filtered(all);
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Text(
                  'Ontdek de perfecte harmonie tussen authentieke ambachtelijke bieren en rijke, smaakvolle gerechten.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.restaurant,
                        title: 'Wat eet je?',
                        subtitle: 'Vind het ideale bier bij jouw gerecht.',
                        isSelected: _mode == _SearchMode.gerecht,
                        onTap: () => _openMode(_SearchMode.gerecht),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.sports_bar,
                        title: 'Wat drink je?',
                        subtitle: 'Vind het perfecte gerecht voor jouw bier.',
                        isSelected: _mode == _SearchMode.bier,
                        onTap: () => _openMode(_SearchMode.bier),
                      ),
                    ),
                  ],
                ),
                if (_mode != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _outlineVariant.withOpacity(0.6)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                      style: GoogleFonts.openSans(color: _onSurface, fontSize: 15),
                      cursorColor: _primary,
                      decoration: InputDecoration(
                        hintText: _mode == _SearchMode.gerecht
                            ? 'Typ een gerecht, bijv. "kaas" of "steak"...'
                            : 'Typ een bier of brouwerij...',
                        hintStyle: GoogleFonts.openSans(color: _onSurfaceVariant),
                        border: InputBorder.none,
                        icon: const Icon(Icons.search, color: _onSurfaceVariant),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_query.trim().isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Begin met typen om combinaties te zien (${all.length} beschikbaar).',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 13),
                      ),
                    )
                  else if (results.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Geen combinaties gevonden voor "$_query".',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 13),
                      ),
                    )
                  else
                    ...results.map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PairingCard(pairing: p),
                        )),
                ] else if (all.isEmpty) ...[
                  const SizedBox(height: 48),
                  Icon(Icons.restaurant_menu, color: _onSurfaceVariant.withOpacity(0.5), size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Er zijn nog geen bier-spijscombinaties toegevoegd.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.openSans(color: _onSurfaceVariant),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? _primary : _outlineVariant.withOpacity(0.6), width: isSelected ? 2 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: _primary, size: 36),
            const SizedBox(height: 10),
            Text(title,
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(color: _onSurface, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _PairingCard extends StatelessWidget {
  final BeerPairing pairing;

  const _PairingCard({required this.pairing});

  Future<void> _openWebsite() async {
    final url = pairing.linkWebsite;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _outlineVariant.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pairing.biernaam,
              style: GoogleFonts.playfairDisplay(color: _primary, fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(pairing.brouwerij, style: GoogleFonts.openSans(color: _onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.restaurant, color: _primary, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(pairing.aanbevolenGerecht, style: GoogleFonts.openSans(color: _onSurface, fontSize: 14)),
              ),
            ],
          ),
          if (pairing.aankoopContext != null || pairing.prijs != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (pairing.aankoopContext != null) _tag(pairing.aankoopContext!),
                if (pairing.prijs != null) _tag(pairing.prijs!),
              ],
            ),
          ],
          if (pairing.linkWebsite != null && pairing.linkWebsite!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _openWebsite,
                icon: const Icon(Icons.open_in_new, color: _primary, size: 16),
                label: Text('Website brouwerij', style: GoogleFonts.openSans(color: _primary, fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tag(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _outlineVariant),
        ),
        child: Text(label, style: GoogleFonts.openSans(color: _onSurface, fontSize: 11)),
      );
}
